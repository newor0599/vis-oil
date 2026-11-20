---One window one instance of oil
---But under same oil class to
---keep track of ids

---@class instance
---@field oil oil
---@field cwd string
---@field original_file string
---@field window vis.window
---@field directory_lines integer
instance = {}
instance.__index = instance

function instance:cd(path)
  if Shell.can_access_path(path) then
    self.cwd = Utils.normalize_path(path)
    return true
  end
  return false
end

---@param ls_out string Output of `ls -laQ`
---@param cwd string Current working directory
---@return Entry[]
function instance:parse_ls(ls_out, cwd)
  local _, header_end = ls_out:find("^total %d+\n")
  ls_out = ls_out:sub(header_end + 1, #ls_out - 1)

  local entries = {}

  local entry_lines = ls_out:gmatch("[^\n]+")

  for line in entry_lines do
    ---@type string[]
    local params = {}
    for param in line:gmatch("[^ ]+") do
      params[#params + 1] = param
    end

    local name = line:match('".*')
    local is_dir = name:sub(-1) == "/"
    if is_dir then
      name = name:sub(1, #name - 1)
    end
    name = name:sub(2, #name - 1)
    name = name:gsub('%" %-%> %"', " -> ")
    name = name:gsub("\\(.)", "%1")

    local no_name = line:gsub('".*', "")
    local permission_bits = params[1]:sub(2, -1)
    local owner_user = params[3]
    local owner_group = params[4]
    local type = params[1]:sub(1, 1)
    local id = self.oil:make_entry_id()
    local date = no_name:sub(-13, -2)
    local size = ""
    for v in no_name:gmatch("[^ ]+") do
      size = v
    end

    local entry = Entry.new(
      type,
      permission_bits,
      owner_user,
      owner_group,
      size,
      date,
      name,
      cwd,
      is_dir,
      id
    )

    entries[#entries + 1] = entry
  end
  return entries
end

---@param cwd? string
---@return Entry[]
function instance:get_entries(cwd)
  if not cwd then
    cwd = self.cwd
  end

  local range = self.oil.entry_cache[cwd]
  local list = {}

  if range then
    ---@type Entry[]
    self.oil:log("Using cache entries")
    for i = range.start, range.finish, 1 do
      list[#list + 1] = self.oil.entry_cache[i]
    end
    return list
  end

  self.oil:log("Grabbing fresh entries")
  local ls_out = Shell.get_ls(self.cwd)
  list = self:parse_ls(ls_out, self.cwd)
  table.move(list, 1, #list, #self.oil.entry_cache + 1, self.oil.entry_cache)
  self.oil.entry_cache[cwd] = { start = list[1].id, finish = list[#list].id }
  return list
end

function instance:get_buffer_content(cwd)
  if cwd == nil then
    cwd = self.cwd
  end
  if self.oil.buffer_cache[cwd] then
    self.oil:log("Using buffer cache")
    return self.oil.buffer_cache[cwd]
  end
  self.oil:log("Using new data")

  local entries = self:get_entries()

  local buffer_content = ""
  local directory_lines = 0

  for _, entry in ipairs(entries) do
    ---@cast entry Entry

    if entry["display_name"] == "./" then
      goto continue
    end

    if entry["is_hidden"] and not self.oil.options.show_hidden then
      goto continue
    end

    local id = Utils.int_to_id(entry.id)
    local name = id .. "| " .. entry["display_name"] .. "\n"
    if entry["is_dir"] then
      directory_lines = directory_lines + #name
    end

    buffer_content = buffer_content .. name
    ::continue::
  end
  return BufferCache.new(buffer_content, directory_lines,
    self.oil.options.show_hidden)
end

function instance:render_entries()
  self.window.file:delete({ start = 0, finish = self.window.file.size })
  local buffer_cache = self:get_buffer_content()

  self.window.file:insert(0, buffer_cache.content)
  self.directory_lines = buffer_cache.dir_highlight
  self.window:draw()
  vis:feedkeys("gg")

  if tostring(self.original_file):gsub("[^/]+$", "") == self.cwd then
    local select_cursor = 0
    local orig_filename = self.original_file:match("[^/]+$")
    for entry in buffer_cache.content:gmatch("[^\n]+") do
      select_cursor = select_cursor + 1
      if entry:gsub(self.oil.NAME_GSUB, "") == orig_filename then
        break
      end
    end
    if select_cursor > 1 then
      vis:feedkeys(tostring(select_cursor) .. "G")
    end
  end

  vis:feedkeys("e")
  vis:feedkeys("3l")

  self.window.file.modified = false
end

function instance:highlight()
  if self.window == nil then
    return
  end
  if self.window.style == nil then
    return
  end
  self.window:style(self.oil.DIR_COLOR, 0, self.directory_lines)
end

function instance:end_instance()
  if self.window == nil then
    return
  end
  vis.events.unsubscribe(vis.events.WIN_CLOSE, self.close_handler)
  vis.events.unsubscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)
  vis.events.unsubscribe(vis.events.FILE_SAVE_PRE, self.pre_write_handler)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.goto_parent)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.interact)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.quit)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.print_cwd)
  self.window.oil = nil
  self = nil
end

function instance:window_closed(win)
  if win ~= self.window then
    return
  end
  vis.events.unsubscribe(vis.events.WIN_CLOSE, self.close_handler)
  vis.events.unsubscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)
end

---@param force? boolean
function instance:clear_data(force)
  if force ~= true then
    for window in vis:windows() do
      ---@cast window vis.window
      if tostring(window.file.name):find("^Oil %d+$") then
        return
      end
    end
  end
  self.oil.window_ids = 0
  self.oil.entry_ids = 0
  self.oil.entry_cache = {}
  self.oil.buffer_cache = {}
end

function instance:cache_buffer(window)
  if window == nil then
    window = self.window
  end
  self.oil.buffer_cache[window.oil.cwd] = BufferCache.new(
    window.file:content(0, window.file.size),
    window.oil.directory_lines,
    self.oil.options.show_hidden
  )
  self.oil:log("Cached buffer for " .. window.oil.cwd)
end

function instance:get_cursor_entry()
  local y = self.window.selection.line
  local x = self.window.selection.col
  vis:feedkeys("V")
  local selection = self.window.selection
  local range = selection.range
  vis:feedkeys("<Escape>")
  self.window.selection:to(y, x)
  local name = self.window.file:content(range)
  name = name:sub(1, #name - 1)
  return name
end

function instance:interact_entry()
  local cursor_content = self:get_cursor_entry()
  cursor_content = cursor_content:match(self.oil.ENTRY_STRUCT)
  if not cursor_content then
    vis:info("Invalid path")
    return
  end
  local id = cursor_content:match(self.oil.ID_MATCH)
  id = tonumber(id, 16)
  local entry = self.oil.entry_cache[id]
  if entry == nil then
    vis:info("Not a valid path")
    return
  end

  local cwd = Utils.normalize_path(self.cwd .. entry.name)
  local can_access = Shell.can_access_path(cwd)
  if not can_access then
    vis:info("No permission to access this path")
    return
  end

  if entry.name ~= "../" then
    if entry.type:find("[-dl]") == nil then
      vis:info("Not an editable ascii file")
      return
    end
  end

  if entry.is_dir then
    if cwd:sub(-1) ~= "/" then
      cwd = cwd .. "/"
    end
    if Shell.can_access_path(cwd) then
      self:cache_buffer()
      self.cwd = Utils.normalize_path(cwd)
      self:render_entries()
    end
  else
    self:end_instance()
    self.window.file = cwd
    self:clear_data()
  end
end

function instance:goto_parent()
  local cwd = Utils.normalize_path(self.cwd .. "../")
  if Shell.can_access_path(cwd) then
    self:cache_buffer()
    self.cwd = cwd
    self:render_entries()
    return
  end
  vis:info("No permission to access this path")
end

---@param content string
---@return Entry[]
function instance:string_to_entry(content)
  local entries = {
    [0] = {},
  }
  for line in content:gmatch("[^\n]+") do
    ---@cast line string
    if line:find(self.oil.ENTRY_STRUCT) then
      local is_dir = line:sub(-1) == "/"
      local id = line:match(self.oil.ID_MATCH)
      id = tonumber(id, 16)
      local entry = self.oil.entry_cache[id]
      local display_name = line:match(" .*")
      display_name = display_name:sub(2, #display_name)
      local name = display_name:gsub(" %-> .*", "")
      entries[#entries + 1] = {
        name = name,
        display_name = display_name,
        path = entry.path,
        id = entry.id,
        is_dir = is_dir,
      }
    else
      entries[0][#entries[0] + 1] = line
    end
  end
  return entries
end

function instance:evaluate_changes(cwd)
  local user_entries = self:string_to_entry(self.oil.buffer_cache[cwd].content)
  local cwd_range = self.oil.entry_cache[cwd]
  local show_hidden = self.oil.buffer_cache[cwd].show_hidden
  local id_check = {}
  local id_delete = {}
  ---@type Actions
  local actions = Actions.new()
  for _, user_entry in ipairs(user_entries) do
    if user_entry.name == self.oil.entry_cache[user_entry.id].name then
      id_check[user_entry.id] = true
    end
  end

  for _, user_entry in ipairs(user_entries) do
    local orig_entry = self.oil.entry_cache[user_entry.id]
    if user_entry.id > cwd_range.finish or user_entry.id < cwd_range.start then
      actions.copy[#actions.copy + 1] = SourceDestination.new(
        orig_entry.path .. orig_entry.name,
        self.cwd .. user_entry.name
      )
    elseif user_entry.name ~= orig_entry.name and not id_check[user_entry.id] then
      id_check[user_entry.id] = true
      actions.move[#actions.move + 1] = SourceDestination.new(
        orig_entry.path .. orig_entry.name,
        self.cwd .. user_entry.name
      )
    elseif user_entry.name ~= orig_entry.name and id_check[user_entry.id] then
      actions.copy[#actions.copy + 1] = SourceDestination.new(
        orig_entry.path .. orig_entry.name,
        self.cwd .. user_entry.name
      )
    end
  end

  for i = cwd_range.start, cwd_range.finish do
    if id_check[i] then
      goto continue
    end
    if self.oil.entry_cache[i].name == "./" then
      goto continue
    end
    if
        self.oil.entry_cache[i].is_hidden and not show_hidden
    then
      goto continue
    end
    id_delete[#id_delete + 1] = i
    actions.delete[#actions.delete + 1] = self.oil.entry_cache[i].path ..
        self.oil.entry_cache[i].name
    ::continue::
  end

  for _, name in ipairs(user_entries[0]) do
    if #name > 0 then
      if name:sub(-1) == "/" then
        actions.dir[#actions.dir + 1] = self.cwd .. name
      else
        actions.file[#actions.file + 1] = self.cwd .. name
      end
    end
  end
  return actions
end

---@param actions_list Actions[]
---@return Actions
function instance:evaluate_cross_cwd_diff(actions_list)
  local actions = Actions.new()
  for index, value in ipairs(actions_list) do
    actions = actions .. value
  end

  if #actions.delete <= 0 then
    return actions
  end

  local copy_set = {}
  local new_move = {}
  local new_delete = {}
  local copy_to_del_index = {}
  ---@cast actions Actions
  for index, value in ipairs(actions.copy) do
    copy_set[value.source] = index
  end

  for _, del_path in ipairs(actions.delete) do
    local copy_index = copy_set[del_path]
    if copy_index then
      new_move[#new_move + 1] = actions.copy[copy_index]
      copy_to_del_index[#copy_to_del_index + 1] = copy_index
      copy_index = nil
    else
      new_delete[#new_delete + 1] = del_path
    end
  end

  table.sort(copy_to_del_index)
  for index, value in ipairs(copy_to_del_index) do
    actions.copy[value - index + 1] = nil
  end

  actions.delete = new_delete
  table.move(new_move, 1, #new_move, #actions.move + 1, actions.move)
  return actions
end

---@param file vis.file
---@param path string
function instance:pre_write_action(file, path)
  -- prevent other instance trigger post write action
  if self.window.file.path ~= path then
    return
  end

  self.oil:log("Executing post write action")
  self:cache_buffer()

  local actions_list = {}
  for cwd, _ in pairs(self.oil.buffer_cache) do
    actions_list[#actions_list + 1] = self:evaluate_changes(cwd)
  end
  local actions = self:evaluate_cross_cwd_diff(actions_list)

  if #tostring(actions) <= 0 then
    vis:info("No changes")
    return
  end

  vis:message(tostring(actions))
  vis:redraw()
  local answer = Utils.prompt_user("Apply changes?", { "no", "yes", "cancel" })
  self.oil:log("User answered " .. tostring(answer))

  if answer == "yes" then
    for _, value in ipairs(actions.file) do
      FileAction.new_file(value)
    end
    for _, value in ipairs(actions.dir) do
      FileAction.new_dir(value)
    end
    for _, value in ipairs(actions.copy) do
      FileAction.copy(value)
    end
    for _, value in ipairs(actions.move) do
      FileAction.move(value)
    end
    for _, value in ipairs(actions.delete) do
      FileAction.delete(value)
    end
    self.oil.entry_cache[self.cwd] = nil
  end

  vis:message("")
  vis:feedkeys("gg")
  vis:feedkeys("V")
  vis:feedkeys("G")
  vis:feedkeys("x")
  vis.win.file = ""
  vis.win:close(true)

  if answer == "yes" or answer == "no" then
    self.oil.buffer_cache[self.cwd] = nil
    self:render_entries()
  end
end

function instance:init()
  self.highlight_handler = function()
    self:highlight()
  end

  self.close_handler = function(win)
    self:window_closed(win)
  end

  self.pre_write_handler = function(file, path)
    self:pre_write_action(file, path)
    return false
  end

  vis.events.subscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)
  vis.events.subscribe(vis.events.WIN_CLOSE, self.close_handler)
  vis.events.subscribe(vis.events.FILE_SAVE_PRE, self.pre_write_handler)

  self.window:map(vis.modes.NORMAL, self.oil.keybinds.goto_parent, function()
    self:goto_parent()
  end)

  self.window:map(vis.modes.NORMAL, self.oil.keybinds.quit, function()
    if not self.window then
      return
    end

    -- Restore original file
    if self.original_file then
      self:end_instance()
      self.window.file = self.original_file
      self:clear_data()
      return
    end

    -- Empty buffer
    self.window.file = ""
    self.window.file:delete({ start = 0, finish = self.window.file.size })
    self.window.file.modified = false
    self.window:draw()
    self:end_instance()
    self:clear_data()
  end)

  self.window:map(vis.modes.NORMAL, self.oil.keybinds.interact, function()
    self:interact_entry()
  end)

  self.window:map(vis.modes.NORMAL, self.oil.keybinds.print_cwd, function()
    vis:info(self.cwd)
  end)

  self.window:map(vis.modes.NORMAL, self.oil.keybinds.toggle_hidden, function()
    self.oil.options.show_hidden = not self.oil.options.show_hidden
    self.oil.buffer_cache[self.cwd] = nil
    self:render_entries()
  end)
end

---@param oil oil Main class
---@param window vis.window A designated window to start a new instance
---@param cwd string Start a new instance at a given working directory
---@param original_file? string Path to original file if available
function instance.new(oil, window, cwd, original_file)
  local new = {
    oil = oil,
    cwd = cwd,
    original_file = original_file,
    window = window,
    directory_lines = 0,
  }
  setmetatable(new, instance)

  new:init()

  return new
end

return instance
