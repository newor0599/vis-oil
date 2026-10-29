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
  for index, entry in ipairs(entries) do
    ---@cast entry Entry
    if self.oil.options["show_hidden"] or not entry["is_hidden"] then
      if entry["is_dir"] then
        self.directory_lines.finish = window_cursor + #entry["display_name"]
      end

      self.window.file:insert(window_cursor, entry["display_name"])
      window_cursor = window_cursor + #entry["display_name"]

      self.window.file:insert(window_cursor, "\n")
      window_cursor = window_cursor + 1

      if entry.name == self.original_file.name then
        select_cursor = index - 1
      end
    end
  end
  self.window:draw()
  vis:feedkeys("gg")
  if select_cursor > 2 then
    select_cursor = select_cursor - 1
    vis:feedkeys(tostring(select_cursor) .. "j")
  end
  self.window.file.modified = false
end

function instance:highlight(win)
  if self.window == win then
    self.window:style(
      self.oil.DIR_COLOR,
      self.directory_lines.start,
      self.directory_lines.finish
    )
  end
end

function instance:close(win)
  if self.window ~= win then
    return
  end

  self.window = nil

  vis.events.unsubscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)
  vis.events.unsubscribe(vis.events.WIN_CLOSE, self.close_handler)
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
  self.highlight_handler = function(win)
    self:highlight(win)
  end

  self.close_handler = function(win)
    self:close(win)
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

    local closed = self.window:close(true)
    if not closed then
      if self.original_file.name ~= nil then
        vis:command("e! " .. self.original_file.path)
      else
        self.window.file = ""
        self.window.file:delete({ start = 0, finish = self.window.file.size })
        self.window.file.modified = false
        self.window:draw()
      end
    end

    self:close(self.window)
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
