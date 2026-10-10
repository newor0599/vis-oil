---@diagnostic disable: unused-function
require("vis-oil.entry")

---@param type string Entry type (directory, file, symlink, etc)
---@param size string Entry size
---@param date string Entry creation date
---@param user_owner string User that owns the entry
---@param group_owner string Group that owns the entry
---@param permissions string Permission bits
---@param name string File name
---@param is_dir boolean Entry is a/to directory
---@param cwd string Current working directory
local function entry_model(
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
	if is_dir and display_name:sub(-1) ~= "/" then
		display_name = display_name .. "/"
	end
	local file_name = name:gsub(" %-%> .*", "")

	local is_hidden = name:sub(1, 1) == "."
	if name == ".." or name == "." then
		is_hidden = false
	end

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
		is_hidden = is_hidden,
	}
end

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

return {
	parse_ls = parse_ls,
}
