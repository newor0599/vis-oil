---@class Entry
---@field path string
---@field is_dir string
---@field type string
---@field size string
---@field date string
---@field user_owner string
---@field group_owner string
---@field permissions string
---@field name string
---@field display_name string
---@field is_hidden string
local Entry = {}

---Create new entry
---@param type string
---@param permissions string
---@param user_owner string
---@param group_owner string
---@param size string
---@param date string
---@param name string
---@param cwd string
---@param is_dir boolean
---@return Entry
function Entry.new(
  type,
  permissions,
  user_owner,
  group_owner,
  size,
  date,
  name,
  cwd,
  is_dir
)
  ---@type string
  local display_name = name
  local file_name = name:gsub(" %-> .*", "")
  if is_dir then
    file_name = file_name .. "/"
  end

  if is_dir and display_name:sub(-1) ~= "/" then
    display_name = display_name .. "/"
  end

  local is_hidden = name:sub(1, 1) == "."
  if name == ".." or name == "." then
    is_hidden = false
  end

  return {
    path = cwd .. file_name,
    is_dir = is_dir,
    type = type,
    size = size,
    date = date,
    user_owner = user_owner,
    group_owner = group_owner,
    permissions = permissions,
    name = file_name,
    display_name = display_name,
    is_hidden = is_hidden,
  }
end

return Entry
