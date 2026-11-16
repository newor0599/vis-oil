---@class Actions
---@field copy SourceDestination[]
---@field move SourceDestination[]
---@field dir string[]
---@field file string[]
---@field delete string[]
local M = {}

function M:stringify()
  local string = ""

  if #self.dir > 0 or #self.file > 0 then
    string = string .. "[NEW]\n"
    for _, path in ipairs(self.file) do
      string = string .. "- " .. path .. "\n"
    end
    for _, path in ipairs(self.dir) do
      string = string .. "- " .. path .. "\n"
    end
  end

  if #self.copy > 0 then
    string = string .. "[COPY]\n"
    for _, srcdst in ipairs(self.copy) do
      string = string
        .. "- "
        .. srcdst.source
        .. " -> "
        .. srcdst.destination
        .. "\n"
    end
  end

  if #self.move > 0 then
    string = string .. "[MOVE]\n"
    for _, srcdst in ipairs(self.move) do
      string = string
        .. "- "
        .. srcdst.source
        .. " -> "
        .. srcdst.destination
        .. "\n"
    end
  end

  if #self.delete > 0 then
    string = string .. "[DELETE]\n"
    for _, path in ipairs(self.delete) do
      string = string .. "- " .. path .. "\n"
    end
  end
  return string
end

function M.new()
  local new = {
    copy = {},
    move = {},
    dir = {},
    file = {},
    delete = {},
  }
  setmetatable(new, {
    __tostring = function(t)
      return M.stringify(t)
    end,
  })
  return new
end

return M
