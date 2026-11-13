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
---@param choices table A list of choice
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
    -- trim newline from selection
    if output:sub(-1) == "\n" then
      choice = output:sub(1, -2)
    else
      choice = output
    end
  end

  vis:redraw()
  return choice
end

return M
