local M = {}

function M.clean_path(path)
  return path:gsub('["\\$`]', "\\%1")
end

function M.new_file(path)
  local stat = io.open(path, "w")
  return stat ~= nil
end

function M.new_dir(path)
  return os.execute('mkdir -p "' .. M.clean_path(path) .. '"')
end

function M.delete(path)
  return os.execute('rm -rf "' .. M.clean_path(path) .. '"')
end

function M.move(srcdst)
  return os.rename(srcdst.source, srcdst.destination)
end

function M.copy(srcdst)
  return os.execute(
    'cp -r "'
    .. M.clean_path(srcdst.source)
    .. '" "'
    .. M.clean_path(srcdst.destination)
    .. '"'
  )
end

return M
