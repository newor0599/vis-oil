---@class BufferCache
---@field content string
---@field dir_highlight integer
local M = {}

---@param content? string
---@param dir_highlight? integer
---@return BufferCache
function M.new(content,dir_highlight)
  return {
    content = content or "",
    dir_highlight = dir_highlight or 0
  }
end
return M
