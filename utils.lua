require("vis-oil.entry")

---@param ls_out string Output of `ls -laQ`
---@param cwd string Current working directory
local function parse_ls(ls_out, cwd)
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

---Copy some element of vis.file to a table
---@param vis_file? vis.file
local function copy_vis_file(vis_file)
  if vis_file == nil then
    return {
      name = "",
      path = "",
      size = 0,
    }
  end
  return {
    name = vis_file.name or "",
    path = vis_file.path or "",
    size = vis_file.size or 0,
  }
end

---@param path string
local function normalize_path(path)
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
  joined = joined .. (is_dir and "/"  or "")
  joined = (absolute and "/" or "") .. joined
  if joined == "" then
    return "."
  end
  return joined
end

return {
  parse_ls = parse_ls,
  copy_vis_file = copy_vis_file,
  normalize_path = normalize_path,
}
