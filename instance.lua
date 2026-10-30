---One window one instance of oil
---But under same oil class to
---keep track of ids

---@class instance
---@field oil oil
---@field cwd string
---@field original_file vis.file
---@field window vis.window
---@field directory_lines vis.range
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

  local ls_out = Shell.get_ls(self.cwd)
  local entries = Utils.parse_ls(ls_out, self.cwd)

  local window_cursor = 0
  local select_cursor = 0
  local visible_lines = 0
  local original_file_name = self.original_file.name:gmatch("[^%/]+$")()
  for _, entry in ipairs(entries) do
    ---@cast entry Entry
    if self.oil.options["show_hidden"] or not entry["is_hidden"] then
      visible_lines = visible_lines + 1
      if entry["is_dir"] then
        self.directory_lines.finish = window_cursor + #entry["display_name"]
      end

      self.window.file:insert(window_cursor, entry["display_name"])
      window_cursor = window_cursor + #entry["display_name"]

      self.window.file:insert(window_cursor, "\n")
      window_cursor = window_cursor + 1

      if entry.name == original_file_name then
        select_cursor = visible_lines
      end
    end
  end
  self.window:draw()
  vis.win = self.window
  vis:feedkeys("gg")
  if select_cursor > 2 then
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
  self.window:style(
    self.oil.DIR_COLOR,
    self.directory_lines.start,
    self.directory_lines.finish
  )
end

function instance:end_instance()
  if self.window == nil then
    return
  end
  vis.events.unsubscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.goto_parent)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.interact)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.quit)
  self.window:unmap(vis.modes.NORMAL, self.oil.keybinds.print_cwd)
  self = nil
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
  local entry_name = self:get_cursor_entry()
  local is_dir = entry_name:sub(-1) == "/"
  entry_name = entry_name:gsub(" %-%> .*", "")
  entry_name = entry_name:gsub(" ", "\\ ")

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
    vis:command("e! " .. cwd)
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

  vis.events.subscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)

  self.window:map(vis.modes.NORMAL, self.oil.keybinds.goto_parent, function()
    self:goto_parent()
  end)

  self.window:map(vis.modes.NORMAL, self.oil.keybinds.quit, function()
    if not self.window then
      return
    end

    -- Restore original file
    if
      self.original_file.name ~= nil
      and self.original_file.name ~= ""
      and self.original_file.name ~= self.window.file.name
    then
      self:end_instance()
      vis:command("e! " .. self.original_file.path:gsub(" ", "\\ "))
      return
    end

    -- Empty buffer
    self.window.file = ""
    self.window.file:delete({ start = 0, finish = self.window.file.size })
    self.window.file.modified = false
    self.window:draw()
    self:end_instance()
  end)

  self.window:map(vis.modes.NORMAL, self.oil.keybinds.interact, function()
    self:interact_entry()
  end)

  self.window:map(vis.modes.NORMAL, self.oil.keybinds.print_cwd, function()
    vis:info(self.cwd)
  end)
end

---@param oil oil Main class
---@param window vis.window A designated window to start a new instance
---@param cwd string Start a new instance at a given working directory
---@param original_file table A vis.window.file copied with utils.copy_vis_file
function instance.new(oil, window, cwd, original_file)
  local new = {
    oil = oil,
    cwd = cwd,
    original_file = original_file,
    window = window,
    directory_lines = { start = 0, finish = 1 },
  }
  setmetatable(new, instance)

  new:init()

  return new
end

return instance
