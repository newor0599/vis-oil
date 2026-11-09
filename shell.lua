local M = {}
---Get current working directory based on currently active window
---@return string cwd Curretn working directory
function M.get_win_cwd()
  local cwd = vis.win.file.path
  if cwd == nil then
    cwd = io.popen("pwd", "r"):lines("a")()
  else
    cwd = cwd:gsub("[^%/]+$", "", 1)
  end
  cwd = cwd:match("[^\n]+")
  if cwd:sub(-1) ~= "/" then
    cwd = cwd .. "/"
  end
  return cwd
end

---@param cwd string Current working directory to list
---@return string # output of ls
function M.get_ls(cwd)
  local ls_out = io.popen('ls -lapQ --group-directories-first "' .. cwd .. '"')
    :lines("a")()
  return ls_out
end

function M.can_access_path(path)
  local data = io.popen('test -r "' .. path .. '" && echo "yes" || echo "no"')
    :lines("a")()
  return data:match("yes") ~= nil
end

return M
