---@class BufferCache
---@field content string
---@field dir_highlight integer
---@field show_hidden boolean
local M = {}

---@param content? string
---@param dir_highlight? integer
---@param show_hidden? boolean
---@return BufferCache
function M.new(content, dir_highlight, show_hidden)
  return {
    content = content or "",
    dir_highlight = dir_highlight or 0,
    show_hidden = show_hidden or false
  }
end

return M
