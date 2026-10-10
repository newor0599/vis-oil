---Get current working directory based on currently active window
---@return string cwd Curretn working directory
local function get_win_cwd()
	local cwd = vis.win.file.path
	if cwd == nil then
		cwd = io.popen("pwd", "r"):lines("a")()
	else
		cwd = cwd:gsub("[^%/]+$", "", 1)
	end
	return cwd:match("[^\n]+") .. "/"
end

local function get_cd_cwd(cd_path)
	local pwd = io.popen("cd " .. cd_path .. ";pwd", "r"):lines("a")()
	return pwd:match("[^\n]+") .. "/"
end

---@param cwd string Current working directory to list
---@return string # output of ls
local function get_ls(cwd)
	local ls_out = io.popen("ls -lapQ --group-directories-first " .. cwd)
		:lines("a")()
	return ls_out
end

return {
	get_cd_cwd = get_cd_cwd,
	get_win_cwd = get_win_cwd,
	get_ls = get_ls,
}
