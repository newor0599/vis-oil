local M = {}

function M.new_file(path)
  local stat = io.open(path, "w")
  return stat ~= nil
end

function M.new_dir(path)
  return os.execute('mkdir -p "' .. path .. '"')
end

function M.delete(path)
  return os.execute('rm -rf "' .. path .. '"')
end

function M.move(srcdst)
  return os.rename(srcdst.source, srcdst.destination)
end

function M.copy(srcdst)
  return os.execute(
    'cp -r "' .. srcdst.source .. '" "' .. srcdst.destination .. '"'
  )
end

return M
