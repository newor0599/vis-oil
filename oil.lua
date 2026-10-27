if not vis.communicate then
  vis:message("Oil Error: file operations requires vis communicate patch")
  return {}
end

Entry = require("vis-oil.entry")
Utils = require("vis-oil.utils")
Shell = require("vis-oil.shell")
Instance = require("vis-oil.instance")
---Main class for oil
---@class oil
oil = {
  DIR_COLOR = vis.ui:style_push("fore:#95AEC7,back:#1C2023"),
  SYM_COLOR = vis.ui:style_push("fore:#C7C795,back:#1C2023"),
  INSTANCE_EXIT_EVENT = "OIL_INSTANCE_EXIT",
  file_ids = 0,
  instances = {},
}

oil.options = {
  show_hidden = false,
}

oil.keybinds = {
  interact = "<Enter>",
  print_cwd = "c",
  quit = "q",
  goto_parent = "H",
  open_buffer = " e",
  open_vertical = " vv",
  open_horizontal = " hh",
}

function oil:map_interact(key)
  self.keybinds.interact = key
end

function oil:map_print_cwd(key)
  self.keybinds.print_cwd = key
end

function oil:map_quit(key)
  self.keybinds.quit = key
end

function oil:map_goto_parent(key)
  self.keybinds.goto_parent = key
end

function oil:map_open_buffer(key)
  vis:unmap(vis.modes.NORMAL, self.keybinds.open_buffer)
  self.keybinds.open_buffer = key
  vis:map(vis.modes.NORMAL, self.keybinds.open_buffer, oil.open_buffer)
end

function oil:map_open_vertical(key)
  vis:unmap(vis.modes.NORMAL, self.keybinds.open_vertical)
  self.keybinds.open_vertical = key
  vis:map(vis.modes.NORMAL, self.keybinds.open_vertical, oil.open_vertical)
end

function oil:map_open_horizontal(key)
  vis:unmap(vis.modes.NORMAL, self.keybinds.open_horizontal)
  self.keybinds.open_horizontal = key
  vis:map(vis.modes.NORMAL, self.keybinds.open_horizontal, oil.open_horizontal)
end


---@param method? "horizontal"|"vertical"|"buffer" Start oil at current buffer/horizontally/vertically (default)
function oil:open(method)
  local cwd = Shell.get_win_cwd()
  local original_file = Utils.copy_vis_file(vis.win.file)

  if method == nil or method == "vertical" then
    method = "vertical"
    vis:command("vsplit Oil")
  elseif method == "horizontal" then
    vis:command("split Oil")
  elseif method == "buffer" then
    vis.win.file = "Oil"
    vis.win:set_syntax("text")
  end

  local window = vis.win
  local instance = Instance.new(self, window, cwd, original_file)

  instance:insert_data()
end

function oil.open_vertical()
  oil:open()
end

function oil.open_horizontal()
  oil:open("horizontal")
end

function oil.open_buffer()
  oil:open("buffer")
end

vis:map(vis.modes.NORMAL, oil.keybinds.open_horizontal, oil.open_horizontal)
vis:map(vis.modes.NORMAL, oil.keybinds.open_vertical, oil.open_vertical)
vis:map(vis.modes.NORMAL, oil.keybinds.open_buffer, oil.open_buffer)

return oil
