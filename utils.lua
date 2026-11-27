require("vis-oil.models.entry")
local M = {}

---@param int integer
---@return string
function M.int_to_id(int)
  return string.format("%03x", int)
end

---@param path string
function M.normalize_path(path)
  if path == "" then
    return "."
  end
  local absolute = path:sub(1, 1) == "/"
  local is_dir = path:sub(-1) == "/"
  local parts = {}

  for seg in path:gmatch("[^/]+") do
    if seg == "." then
    elseif seg == ".." then
      if #parts > 0 and parts[#parts] ~= ".." then
        table.remove(parts)
      elseif not absolute then
        parts[#parts + 1] = ".."
      end
    else
      parts[#parts + 1] = seg
    end
  end
  local joined = table.concat(parts, "/")
  joined = joined .. (is_dir and "/" or "")
  joined = (absolute and "/" or "") .. joined
  if joined == "" then
    return "."
  end
  return joined
end

---Prompt user question with vis-menu
---@param prompt string The title of the prompt
---@param choices string[] A list of choice
---@return string?
function M.prompt_user(prompt, choices)
  choices = table.concat(choices, "\n")

  local cmd = "vis-menu"

  if prompt then
    cmd = cmd .. " -p '" .. prompt .. "'"
  end

  local choice = nil
  local status, output = vis:pipe(choices, cmd)
  if status == 0 then
    if output:sub(-1) == "\n" then
      choice = output:sub(1, -2)
    else
      choice = output
    end
  end

  vis:redraw()
  return choice
end

function M.round(num, places)
  local mult = 10 ^ (places or 0)
  return math.floor(num * mult + 0.5) / mult
end

function M.human_size(bytes, decimal)
  decimal = decimal or 0
  if bytes == 0 then return "0 B" end
  local units = { "B", "KB", "MB", "GB", "TB", "PB" }
  local i = 1
  while bytes >= 1024 and i < #units do
    bytes = bytes / 1024
    i = i + 1
  end

  if i == 1 then
    return string.format("%d %s", bytes, units[i])
  end

  bytes = tostring(M.round(bytes, decimal)):gsub("%.[0]+$", "")

  return string.format("%s %s", bytes, units[i])
end

---@param entry Entry
---@param attr_list Attributes[]
---@param format_func function
function M.parse_attr_list(entry, attr_list, format_func)
  if not entry or #attr_list <= 0 then
    return ""
  end
  format_func = format_func or function(str)
    return str
  end
  local attr_str = ""
  for _, value in ipairs(attr_list) do
    if value == "size" then
      attr_str = attr_str .. format_func(M.human_size(entry.size, 1))
    elseif value == "B" then
      attr_str = attr_str .. format_func(entry.size .. "B")
    elseif value == "KB" then
      attr_str = attr_str .. format_func(M.round(entry.size / 1024 ^ 1, 1) .. "KB")
    elseif value == "MB" then
      attr_str = attr_str .. format_func(M.round(entry.size / 1024 ^ 2, 1) .. "MB")
    elseif value == "GB" then
      attr_str = attr_str .. format_func(M.round(entry.size / 1024 ^ 3, 1) .. "GB")
    elseif value == "TB" then
      attr_str = attr_str .. format_func(M.round(entry.size / 1024 ^ 4, 1) .. "TB")
    elseif value == "PB" then
      attr_str = attr_str .. format_func(M.round(entry.size / 1024 ^ 5, 1) .. "PB")
    elseif value == "permissions" then
      attr_str = attr_str .. format_func(entry.permissions)
    elseif value == "filetype" then
      attr_str = attr_str .. format_func(entry.type)
    elseif value == "date" then
      attr_str = attr_str .. format_func(os.date("%c", entry.date))
    elseif value:find("%%") then
      attr_str = attr_str .. format_func(os.date(value, entry.date))
    elseif value == "user owner" then
      attr_str = attr_str .. format_func(entry.user_owner)
    elseif value == "group owner" then
      attr_str = attr_str .. format_func(entry.group_owner)
    end
  end
  return attr_str
end

---@param entries Entry[]
---@param methods sorts[]
function M.sort_entries(entries, methods)
  local function conditions(a, b, method)
    ---@cast a Entry
    ---@cast b Entry
    local invert = method:sub(-2) == " d"
    if a.date ~= b.date and (method:find("modified") or false) then
      return (a.date < b.date) ~= invert
    end
    if a.is_dir ~= b.is_dir and (method:find("directory") or false) then
      return a.is_dir ~= invert
    end
    if a.is_hidden ~= b.is_hidden and (method:find("hidden") or false) then
      return a.is_hidden ~= invert
    end
    if a.size ~= b.size and (method:find("size") or false) then
      return (a.size < b.size) ~= invert
    end
    if a.name ~= b.name and (method:find("name") or false) then
      return (a.name < b.name) ~= invert
    end
  end

  table.sort(entries, function(a, b)
    if (a.name == "../") ~= (b.name == "../") then
      return a.name == "../"
    end
    for _, method in ipairs(methods) do
      local sort = conditions(a, b, method)
      if sort ~= nil then
        return sort
      end
    end
    return a.name < b.name
  end)
end

---@param s string
function M.utf8_len(s)
  s = tostring(s) or ""
  return utf8.len(s, 1, #s)
end

return M
