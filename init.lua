require("vis")
if not vis.communicate then
  vis:message("Oil Error: file operations requires vis communicate patch")
  return {}
end

---@param type string Entry type (directory, file, symlink, etc)
---@param size string Entry size
---@param date string Entry creation date
---@param user_owner string User that owns the entry
---@param group_owner string Group that owns the entry
---@param permissions string Permission bits
---@param name string File name
---@param is_dir boolean Entry is a/to directory
---@param cwd string Current working directory
local function entry_model(type, permissions, user_owner, group_owner, size, date, name, cwd, is_dir)
  ---@type string
  local display_name = name
  local file_name = name:gsub(" %-%> .*","")
  return {
    path = cwd .. name,
    is_dir = is_dir,
    type = type,
    size = size,
    date = date,
    user_owner = user_owner,
    group_owner = group_owner,
    permissions = permissions,
    name = file_name,
    display_name = display_name,
    is_hidden = name:sub(1, 1) == ".",
  }
end

---@class oil
---@field oil_window? vis.window
oil = {
  directory_lines = {},
  symlink_lines = {},
  DIR_COLOR = vis.ui:style_push("fore:#95AEC7,back:#1C2023"),
  SYM_COLOR = vis.ui:style_push("fore:#C7C795,back:#1C2023"),
  oil_window = nil,
}

---@param self oil
function oil.setup(self)
  vis.events.subscribe(vis.events.START, function()
    for key, value in pairs(vis.ui.style_ids) do
      vis:insert(key .. " " .. value)
      vis:insert("\n")
    end
  end)

  vis.events.subscribe(vis.events.WIN_HIGHLIGHT, function()
    if self.oil_window then
      for _, range in ipairs(self.directory_lines) do
        self.oil_window:style(self.DIR_COLOR, range["start"], range["end"])
      end
    end
  end)

  vis.events.subscribe(vis.events.WIN_CLOSE, function(win)
    if win == self.oil_window then
      self.oil_window = nil
    end
  end)
end

---Get current working directory based on currently active window
---@return string cwd Curretn working directory
function oil._get_cwd(self)
  local cwd = vis.win.file.path
  if cwd == nil then
    cwd = io.popen("pwd", "r"):lines("a")()
  else
    cwd = cwd:gsub("[^%/]+$", "", 1)
  end
  return cwd:match("[^\n]+") .. "/"
end

---@param cwd string Current working directory to list
---@return string # output of ls
function oil._get_ls(self, cwd)
  local ls_out = io.popen("ls -lapQ --group-directories-first " .. cwd):lines("a")()
  return ls_out
end

---@param ls_out string Output of `ls -laQ`
---@param cwd string Current working directory
function oil._parse_ls(self, ls_out, cwd)
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

    local name = table.concat(params, " ", 9, #params)
    local is_dir = name:sub(-1) == "/"
    if is_dir then
      name = name:sub(1, #name - 1)
    end
    name = name:sub(2, #name - 1)
    name = name:gsub('%" %-%> %"', " -> ")

    local entry = entry_model(
      params[1]:sub(1, 1),
      params[1]:sub(2, #params[1]),
      params[3],
      params[4],
      params[5],
      params[6] .. " " .. params[7] .. " " .. params[8],
      name,
      cwd,
      is_dir
    )
    entries[#entries + 1] = entry
  end
  return entries
end

function oil._insert_data(self, entries)
  local window_cursor = 0
  for _, entry in ipairs(entries) do
    if entry["is_dir"] then
      local directory_range = { start = window_cursor, ["end"] = window_cursor + #entry["display_name"] }
      self.directory_lines[#self.directory_lines + 1] = directory_range
    end

    self.oil_window.file:insert(window_cursor, entry["display_name"])
    window_cursor = window_cursor + #entry["display_name"]
    if entry["is_dir"] then
      self.oil_window.file:insert(window_cursor, "/")
      window_cursor = window_cursor + 1
    end

    self.oil_window.file:insert(window_cursor, "\n")
    window_cursor = window_cursor + 1
  end
end

---@param layout? "horizontal"|"vertical" Start oil horizontally or vertically (default)
function oil.open(self, layout)
  if layout == nil then
    layout = "vertical"
  end

  local cwd = self:_get_cwd()
  local ls_out = self:_get_ls(cwd)
  local entries = self:_parse_ls(ls_out, cwd)

  vis:command("vnew")
  self.oil_window = vis.win
  self:_insert_data(entries)

  if self.oil_window.file.name == nil then
    vis:feedkeys("gg")
  end

  self.oil_window:map(vis.modes.NORMAL, "q", function()
    self.oil_window:close(true)
  end)

  vis.events.subscribe(vis.events.INPUT, function(keys)
    if keys == "dd" then
      self.oil_window.file:snapshot()
    end
  end)
end

function oil.open_vertical(self)
  self.open()
end

function oil.open_horizontal(self)
  self:open("horizontal")
end
