---One window one instance of oil
---But under same oil class to
---keep track of ids

---@class instance
---@field oil oil
---@field cwd string
---@field original_file string
---@field window vis.window
---@field directory_lines integer
---@field active_entries table
---@field reviewing_changes? table | true A table with data for backup or nil
---@field dialog string?
instance = {}
instance.__index = instance

function instance:cd(path)
  if Shell.can_access_path(path) then
    self.cwd = path
    return true
  end
  return false
end

function instance:insert_data()
  self.window.file:delete({ start = 0, finish = self.window.file.size })
  self.active_entries = {}
  self.reviewing_changes = nil

  local ls_out = Shell.get_ls(self.cwd)
  local entries = Utils.parse_ls(ls_out, self.cwd)

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

    local name
    if entry["display_name"] == "../" then
      name = entry["display_name"] .. "\n"
    else
      table.insert(self.active_entries, entry)
      name = "#" .. #self.active_entries .. "| ".. entry["display_name"] .. "\n"
    end

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
  if select_cursor > 2 then
    vis:feedkeys(tostring(select_cursor) .. "G")
  end
  self.window.file.modified = false
end

function instance:show_changes(contents, changes_amnt)
  local file = self.window.file
  local backup = file:content(0, file.size)
  local backup_dir_lines = self.directory_lines
  if not file:delete(0, file.size) then
    file:insert(0, backup)
    if not self.dialog then self.dialog = "Error: could not show changes" end
    return false
  end
  self.directory_lines = 0

  local height = self.window.height - 2
  local buffer = {}

  contents.create_highlight = 0
  for _, i in ipairs(contents.tocreate) do
    local str = "CREATE " .. Utils.normalize_path(i)
    table.insert(buffer, str)
    contents.create_highlight = contents.create_highlight + #str + 1
  end
  contents.copy_highlight = contents.create_highlight
  for _, i in ipairs(contents.tocopy) do
    local fmt = string.format("COPY %s -> %s", i[1].name, Utils.normalize_path(i[2]))
    table.insert(buffer, fmt)
    contents.copy_highlight = contents.copy_highlight + #fmt + 1
  end
  contents.move_highlight = contents.copy_highlight
  for _, i in ipairs(contents.tomove) do
    local fmt = string.format("MOVE %s -> %s", i[1].name, Utils.normalize_path(i[2]))
    table.insert(buffer, fmt)
    contents.move_highlight = contents.move_highlight + #fmt + 1
  end
  contents.delete_highlight = contents.move_highlight
  for _, i in ipairs(contents.todelete) do
    local fmt = string.format("DELETE %s", i.name)
    table.insert(buffer, fmt)
    contents.delete_highlight = contents.delete_highlight + #fmt + 1
  end
  buffer = table.concat(buffer, "\n")
  if changes_amnt > height then
    -- They don't fit: let user scroll
    local header = "Save the buffer to apply the following changes (scroll for more):\n\n"
    file:insert(0, header)
    file:insert(#header, buffer)
    self.window:draw()
    vis:redraw()
    -- Events temporarily disabled
    self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.goto_parent)
    self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.interact)
    self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.print_cwd)
    self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.toggle_hidden)
    local readonly_handler = Utils.readonly_buffer_ehandler(self.window)
    vis.events.subscribe(vis.events.INPUT, readonly_handler)

    self.reviewing_changes = {
      contents = contents,
      backup = backup,
      directory_lines = backup_dir_lines,
      readonly_handler = readonly_handler
    }
    return false
  else
    -- They DO fit: prompt immediately
    file:insert(0, buffer)
    self.reviewing_changes = {
      contents = contents
    }; -- For styles!
    self.window:draw()
    vis:redraw()
    local answer = Utils.prompt_user("Apply these changes?", {"Yes", "No"})

    if answer ~= "Yes" then
      self.directory_lines = backup_dir_lines
      self.reviewing_changes = nil
      file:delete(0, file.size)
      file:insert(0, backup)
      self.window:draw()
      vis:redraw()
    end

    return answer == "Yes"
  end
end

function instance:apply_changes(contents)
  for _, i in ipairs(contents.tocreate) do
      local ok, error = Fs.create(i, Utils.normalize_path(self.cwd .. i))
      if not ok then
        if not self.dialog then self.dialog = error end
        return false
      end
  end
  for _, i in ipairs(contents.tocopy) do
      local ok, error = Fs.copy(
        i[1].name,
        Utils.normalize_path(i[1].path .. i[1].name),
        i[2],
        Utils.normalize_path(self.cwd .. i[2])
      )
      if not ok then
        if not self.dialog then self.dialog = error end
        return false
      end
  end
  for _, i in ipairs(contents.tomove) do
      local ok, error = Fs.move(
        i[1].name,
        Utils.normalize_path(i[1].path .. i[1].name),
        i[2],
        Utils.normalize_path(self.cwd .. i[2])
      )
      if not ok then
        if not self.dialog then self.dialog = error end
        return false
      end
  end
  for _, i in ipairs(contents.todelete) do
    local ok, error = Fs.delete(i.name, Utils.normalize_path(i.path .. i.name))
    if not ok then
      if not self.dialog then self.dialog = error end
      return false
    end
  end
  return true
end

function instance:file_save_event(file)
  if vis.win ~= self.window then return true end
  if not self.active_entries then
    if not self.dialog then self.dialog = "Error with Oil instance" end
    return false
  end

  if self.reviewing_changes then
    assert(type(self.reviewing_changes) == "table")
    local answer = Utils.prompt_user("Apply?", {"Yes", "No"})

    if answer == "Yes" then
      local ok, error = self:apply_changes(self.reviewing_changes.contents)
      -- Events are back up!
      self.window:map(vis.modes.NORMAL, self.oil.keybinds.goto_parent, function()
        self:goto_parent()
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
      vis.events.unsubscribe(vis.events.INPUT, self.reviewing_changes.readonly_handler)

      self:insert_data()
      self.reviewing_changes = nil
      self.window:draw()
      vis:redraw()
      if not ok and not self.dialog then self.dialog = error end
      return false
    elseif answer == "No" then
      self.directory_lines = self.reviewing_changes.directory_lines
      file:delete(0, file.size)
      file:insert(0, self.reviewing_changes.backup)
      self.window:draw()
      vis:redraw()
      self.window:map(vis.modes.NORMAL, self.oil.keybinds.goto_parent, function()
        self:goto_parent()
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
      vis.events.unsubscribe(vis.events.INPUT, self.reviewing_changes.readonly_handler)
      self.reviewing_changes = nil
      return false
    else
      return false
    end
  end
  local contents = {}
  contents.tocreate = {}
  contents.todelete = {}
  contents.tomove = {}
  contents.tocopy = {}

  local i = 0;
  local changes_amnt = 0;
  for line in file:lines_iterator() do
    i = i + 1
    if line == "../" then goto continue end

    -- Anything starting with ../ is error (only child of cwd)
    local id, filename = line:match("^%#(%d+)|%s*(.*)$")
    if not id then
      filename = Utils.string_trim(line)
    else
      filename = Utils.string_trim(filename)
    end

    if filename:match("^%.%./.*$") then
      if not self.dialog then self.dialog = "Error line " .. i .. ": cannot modify/create entries outside of cwd" end
      return false
    -- Any path that normalizes to cwd ("." or "/") is an error (cwd cannot change)
    elseif Utils.normalize_path(filename):match("^[%.%/]$") then
      if not self.dialog then self.dialog = "Error line " .. i .. ": cannot modify/create cwd ('.') as if it were a file" end
      return false
    end

    if not id then
      -- New entry to create
      if filename == "" then goto continue end
      local ok, dup_name = Fs.deduplicate(contents, filename)
      if not ok then
        if not self.dialog then self.dialog = "Error line " .. i .. ": Duplicated entries '" .. dup_name .. "'" end
        return false
      end

      table.insert(contents.tocreate, filename)
      changes_amnt = changes_amnt + 1
    else
      filename = filename:gsub(" %-%> .*$", "")
      Utils.string_trim(filename)
      if filename == "" then
        if not self.dialog then self.dialog = "Error line " .. i .. ": Invalid unnamed entry with an id" end
        return false
      end
      local ok, dup_name = Fs.deduplicate(contents, filename)
      if not ok then
        if not self.dialog then self.dialog = "Error line " .. i .. ": Duplicated entries '" .. dup_name .. "'" end
        return false
      end

      local id = tonumber(id)
      ---@cast id number
      if id > #self.active_entries then
        if not self.dialog then self.dialog = "Error line " .. i .. ": do not create new file with a dummy id" end
        return false
      end
      local original_entry = self.active_entries[id]
      local is_dir = filename:sub(-1) == "/"

      if not contents[id] then
        contents[id] = {}
      end

      if filename == original_entry.name then
          -- Set if the original file entry is kept somewhere
          contents[id][0] = true
      else
        -- List of variations of the original entry. If index 0 is not set, the
        -- first entry is the one the original file will be renamed/moved into, the others
        -- will be copies. Not that it matters.
        if original_entry.is_dir ~= is_dir then
          if not self.dialog then
            self.dialog = "Error line " .. i .. ": Cannot change type of entry. Delete and create an entry with the same name"
          end
          return false
        end
        table.insert(contents[id], filename)
      end
    end
    ::continue::
  end

  for i = 1, #self.active_entries do
    local entry = self.active_entries[i]
    local instances = contents[i]
    if not instances then
        -- Delete
        table.insert(contents.todelete, entry)
        changes_amnt = changes_amnt + 1
        goto continue
    end
    local copyfrom = 1
    if not instances[0] then copyfrom = 2 end

    for j = copyfrom, #instances do
      local copy = instances[j]
      -- Create all copies
      table.insert(contents.tocopy, {entry, copy})
      changes_amnt = changes_amnt + 1
    end

    if copyfrom == 2 then
      -- Move to first
      table.insert(contents.tomove, { entry, instances[1] })
      changes_amnt = changes_amnt + 1
    end
    ::continue::
  end


  if #contents.tocreate + #contents.tocopy + #contents.todelete + #contents.tomove == 0 then
      self:insert_data()
      return false
  end
  local apply = self:show_changes(contents, changes_amnt)
  local applied = false
  if apply then
    local ok, err = self:apply_changes(contents)
    self.reviewing_changes = nil
    if ok then
      applied = true
    else
      if not self.dialog then self.dialog = err end
    end
    self:insert_data()
  end
  return false, applied
end

function instance:highlight()
  if self.window == nil then
    return
  end
  if self.window.style == nil then
    return
  end
  if not self.window.file.modified then
    self.window:style(self.oil.DIR_COLOR, 0, self.directory_lines)
  elseif self.reviewing_changes then
    local c = self.reviewing_changes.contents
    if c.create_highlight ~= 0 then
      self.window:style(self.oil.CREATE_COLOR, 0, c.create_highlight)
    end
    if c.copy_highlight ~= c.create_highlight then
      self.window:style(self.oil.COPY_COLOR, c.create_highlight, c.copy_highlight)
    end
    if c.move_highlight ~= c.copy_highlight then
      self.window:style(self.oil.MOVE_COLOR, c.copy_highlight, c.move_highlight)
    end
    if c.delete_highlight ~= c.move_highlight then
      self.window:style(self.oil.DELETE_COLOR, c.move_highlight, c.delete_highlight)
    end
  end
  -- When using vis:info during file_save_event and blocking the save operation
  -- by returning false, the message initially sent with vis:info gets overwritten
  -- by a default message about the save being blocked by a pre-hook. This system
  -- with self.dialog is meant to prevent that.
  if self.dialog then
    vis:info(self.dialog)
    self.dialog = nil
  end
end

function instance:end_instance()
  if self.window == nil then
    return
  end
  vis.events.unsubscribe(vis.events.WIN_CLOSE, self.close_handler)
  vis.events.unsubscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)
  vis.events.unsubscribe(vis.events.FILE_SAVE_PRE, self.save_handler)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.goto_parent)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.interact)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.quit)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.print_cwd)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.toggle_hidden)
  self = nil
end

function instance:window_closed(win)
  if win ~= self.window then
    return
  end
  vis.events.unsubscribe(vis.events.WIN_CLOSE, self.close_handler)
  vis.events.unsubscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)
  vis.events.unsubscribe(vis.events.FILE_SAVE_PRE, self.save_handler)
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
  local name = self.window.file:content(range):sub(1, -2)

  if name ~= "../" then
    local ok, start = name:find("| ", 1, true)
    if not ok then return end
    name = name:sub(start + 1)
  end
  return name
end

function instance:interact_entry()
  local entry_name = self:get_cursor_entry()
  Utils.string_trim(entry_name)
  if not entry_name then return end
  local is_dir = entry_name:sub(-1) == "/"
  entry_name = entry_name:gsub(" %-%> .*", "")
  if #entry_name <= 0 then
    return
  end

  local cwd = Utils.normalize_path(self.cwd .. entry_name)
  local can_access = Shell.can_access_path(cwd)
  if not can_access then
    vis:info("No permission to access this path")
    return
  end
  if is_dir then
    self:cd(cwd)
    self:insert_data()
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

  self.save_handler = function(file)
    local ok, applied = self:file_save_event(file)
    if applied then self.dialog = "Changes applied successfully!" end
    return ok
  end

  vis.events.subscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)
  vis.events.subscribe(vis.events.WIN_CLOSE, self.close_handler)
  vis.events.subscribe(vis.events.FILE_SAVE_PRE, self.save_handler)

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
