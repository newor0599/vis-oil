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

    local name = line:gmatch('".*')()
    local is_dir = name:sub(-1) == "/"
    if is_dir then
      name = name:sub(1, #name - 1)
    end
    name = name:sub(2, #name - 1)
    name = name:gsub('%" %-%> %"', (is_dir and "/" or "") .. " -> ")

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

function instance:insert_data()
  self.window.file:delete({ start = 0, finish = self.window.file.size })

  local entries = self:get_entries()

  local buffer_content = ""
  local select_cursor = 0
  local visible_lines = 0
  local original_file_name = tostring(self.original_file):gmatch("[^%/]+$")()
  self.directory_lines = 0

  for _, entry in ipairs(entries) do
    ---@cast entry Entry

    if entry["display_name"] == "./" then
      goto continue
    end

    if entry["is_hidden"] and not self.oil.options.show_hidden then
      goto continue
    end

    visible_lines = visible_lines + 1
    local id = Utils.int_to_id(entry.id)
    local name = "/" .. id .. " " .. entry["display_name"] .. "\n"
    if entry["is_dir"] then
      self.directory_lines = self.directory_lines + #name
    end

    buffer_content = buffer_content .. name

    if entry.name == original_file_name then
      select_cursor = visible_lines
    end
    ::continue::
  end

  self.window.file:insert(0, buffer_content)
  self.window:draw()
  vis.win = self.window
  vis:feedkeys("gg")
  if select_cursor > 1 then
    vis:feedkeys(tostring(select_cursor) .. "G")
  end
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
  local id = cursor_content:gmatch("/[a-f0-9]+ ")()
  id = cursor_content:sub(2, #id)
  id = tonumber(id, 16)
  local entry = self.oil.entry_cache[id]
  if entry == nil then
    vis:info("No permission to access this path")
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
    if self:cd(cwd) then
      self:insert_data()
    end
  else
    self:end_instance()
    vis:command('e! "' .. cwd .. '"')
    self:clear_data()
  end
end

function instance:goto_parent()
  local cwd = Utils.normalize_path(self.cwd .. "../")
  if self:cd(cwd) then
    self:insert_data()
    return
  end
  vis:info("No permission to access this path")
end

function instance:init()
  self.highlight_handler = function()
    self:highlight()
  end

  self.close_handler = function(win)
    self:window_closed(win)
  end

  vis.events.subscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)
  vis.events.subscribe(vis.events.WIN_CLOSE, self.close_handler)

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
      vis:command('e! "' .. self.original_file .. '"')
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
    self:insert_data()
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
