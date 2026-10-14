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
---@param vis_file vis.file
local function copy_vis_file(vis_file)
  return {
    name = vis_file.name,
    path = vis_file.path,
    size = vis_file.size,
  }
end

return {
  parse_ls = parse_ls,
  copy_vis_file = copy_vis_file,
}
