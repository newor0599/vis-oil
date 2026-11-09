require("vis-oil.entry")
local M = {}

---@param ls_out string Output of `ls -laQ`
---@param cwd string Current working directory
function M.parse_ls(ls_out, cwd)
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
    name = name:gsub('%" %-%> %"', (is_dir and "/" or "") .. " -> ")

    local entry = Entry.new(
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
