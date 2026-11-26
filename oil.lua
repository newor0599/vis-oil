if not vis.communicate then
  vis:message("Oil Error: file operations requires vis communicate patch")
  return {}
end
if not vis.events then
  vis:message("Oil Error: directory highlight requires vis events patch")
  return {}
end
if not vis.ui then
  vis:message("Oil Error: directory highlight requires vis ui patch")
  return {}
end

Entry = require("vis-oil.models.entry")
Utils = require("vis-oil.utils")
Shell = require("vis-oil.shell")
Instance = require("vis-oil.instance")
Help = require("vis-oil.help")
SourceDestination = require("vis-oil.models.srcdst")
FileAction = require("vis-oil.fileaction")
Actions = require("vis-oil.models.actions")
BufferCache = require("vis-oil.models.buffer_cache")


---Main class for oil
---@class oil
---@field entry_cache EntryCache
---@field buffer_cache BufferCache[]
oil = {
  window_ids = 0,
  entry_ids = 0,
  entry_cache = {},
  buffer_cache = {},
}

---@class oil.options
---@field show_hidden boolean
---@field debug boolean
---@field sort sorts[]
---@field attributes Attributes[]
oil.options = {
  show_hidden = true, --- Show hidden
  debug = false, --- Show debug messages
  ---@type sorts[]
  sort = { "directory", "hidden", "size d" }, --- Sort methods
  ---@type Attributes[]
  attributes = {}, ---strftime for custom time format, or other option
  separator = "│ " ---Set seperator for the info column
}

oil.const = {
  DIR_COLOR = vis.ui:style_push("fore:#95AEC7"),
  SYM_COLOR = vis.ui:style_push("fore:#C7C795"),
  CREATE_COLOR = vis.ui:style_push("fore:#ff9e3b"),
  COPY_COLOR = vis.ui:style_push("fore:#d61a1a"),
  MOVE_COLOR = vis.ui:style_push("fore:#98bb6c"),
  DELETE_COLOR = vis.ui:style_push("fore:#b1459f"),
  ID_MATCH = "[a-f0-9]+",
}

setmetatable(oil.const, {
  __index = function(t, key)
    if key == "ID_GSUB" then
      return "^[a-f0-9]+.*" .. oil.options.separator
    end
    if key == "ENTRY_STRUCT" then
      return "^[a-f0-9]+" .. oil.options.separator .. ".*"
    end
    return nil
  end
})

function oil:make_window_id()
  self.window_ids = self.window_ids + 1
  return self.window_ids
end

function oil:make_entry_id()
  self.entry_ids = self.entry_ids + 1
  return self.entry_ids
end

---@param message string
function oil:log(message)
  if self.options.debug then
    local current_win = vis.win
    vis:message(message)
    vis.win = current_win
  end
end

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
  local original_file = nil

  if method == "horizontal" then
    vis:command("new")
  elseif method == "buffer" then
    if vis.win.oil then
      return
    end
    if vis.win.file.modified then
      local ans = Utils.prompt_user("Save changes?", { "yes", "no", "cancel" })
      if ans == nil then
        return
      end
      if ans == "cancel" then
        return
      elseif ans == "no" then
      else
        vis:command("w")
      end
    end
    if vis.win.file.name then
      original_file = vis.win.file.path
    end
    vis.win:set_syntax("text")
  else
    method = "vertical"
    vis:command("vnew")
  end

  local window_id = self:make_window_id()
  local window_name = "Oil " .. tostring(window_id)
  local cwd = Shell.get_win_cwd()

  local window = vis.win
  window.file = ""
  window.file = window_name
  local instance = Instance.new(self, window, cwd, original_file)
  window.oil = instance

  instance:render_entries()
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

function oil.init()
  vis:map(vis.modes.NORMAL, oil.keybinds.open_horizontal, oil.open_horizontal)
  vis:map(vis.modes.NORMAL, oil.keybinds.open_vertical, oil.open_vertical)
  vis:map(vis.modes.NORMAL, oil.keybinds.open_buffer, oil.open_buffer)
end

function oil:dump_entry_cache()
  for cwd, range in pairs(oil.entry_cache) do
    if tostring(cwd):find("^%d+") then
      goto continue
    end
    vis:message(cwd)
    vis:message(
      string.format(
        "Range Start %s Finish %s",
        tostring(range.start),
        tostring(range.finish)
      )
    )
    for i = range.start, range.finish do
      vis:message(oil.entry_cache[i].id .. " " .. oil.entry_cache[i].name)
    end
    vis:message("")
    ::continue::
  end
end

vis:command_register("oil", function(argv)
  if argv[1] == "debug" then
    if argv[2] == "window" then
      local win = vis.win
      if win.oil then
        vis:message("Original file: " .. (win.oil.original_file or "NaN"))
      else
        vis:message("Not an oil window")
      end
      vis.win = win
    end
    if argv[2] == "entry-cache" then
      oil:dump_entry_cache()
      vis:message("")
    end
  end
  if argv[1] == "help" then
    vis:message(Help.message)
  end
  if argv[1] == "open" then
    if argv[2] == "buffer" then
      oil.open_buffer()
    end
    if argv[2]:sub(1, 1) == "v" then
      oil.open_vertical()
    end
    if argv[2]:sub(1, 1) == "h" then
      oil.open_horizontal()
    end
  end
  if argv[1] == "redraw" then
    local oil = vis.win.oil
    if oil then
      vis.win.oil:insert_data()
    end
  end
end)

vis.events.subscribe(vis.events.INIT, function()
  oil.const.DIR_COLOR = vis.ui:style_push("fore:#95AEC7")
  oil.const.SYM_COLOR = vis.ui:style_push("fore:#C7C7ff")
  oil.const.CREATE_COLOR = vis.ui:style_push("fore:#ff9e3b")
  oil.const.COPY_COLOR = vis.ui:style_push("fore:#d61a1a")
  oil.const.MOVE_COLOR = vis.ui:style_push("fore:#98bb6c")
  oil.const.DELETE_COLOR = vis.ui:style_push("fore:#b1459f")
end)

setmetatable(oil, { __call = oil.init })
return oil
