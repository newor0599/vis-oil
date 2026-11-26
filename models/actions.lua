---@class Actions
---@field copy SourceDestination[]
---@field move SourceDestination[]
---@field dir string[]
---@field file string[]
---@field delete string[]

local M = {}

---@param t1 Actions
---@param t2 Actions
---@return Actions
function M.concat(t1, t2)
  table.move(t2.copy or {}, 1, #(t2.copy or {}), #(t1.copy or {}) + 1, t1.copy or {})
  table.move(t2.move or {}, 1, #(t2.move or {}), #(t1.move or {}) + 1, t1.move or {})
  table.move(t2.dir or {}, 1, #(t2.dir or {}), #(t1.dir or {}) + 1, t1.dir or {})
  table.move(t2.file or {}, 1, #(t2.file or {}), #(t1.file or {}) + 1, t1.file or {})
  table.move(t2.delete or {}, 1, #(t2.delete or {}), #(t1.delete or {}) + 1,
             t1.delete or {})
  return t1
end

---@param t Actions
---@return string
function M.tostring(t)
  local string = ""

  if #t.dir > 0 or #t.file > 0 then
    string = string .. "[NEW]\n"
    for _, path in ipairs(t.file) do
      string = string .. "- " .. path .. "\n"
    end
    for _, path in ipairs(t.dir) do
      string = string .. "- " .. path .. "\n"
    end
    string = string .. "\n"
  end

  if #t.copy > 0 then
    string = string .. "[COPY]\n"
    for _, srcdst in ipairs(t.copy) do
      string = string
          .. "- "
          .. srcdst.source
          .. " -> "
          .. srcdst.destination
          .. "\n"
    end
    string = string .. "\n"
  end

  if #t.move > 0 then
    string = string .. "[MOVE]\n"
    for _, srcdst in ipairs(t.move) do
      string = string
          .. "- "
          .. srcdst.source
          .. " -> "
          .. srcdst.destination
          .. "\n"
    end
    string = string .. "\n"
  end

  if #t.delete > 0 then
    string = string .. "[DELETE]\n"
    for _, path in ipairs(t.delete) do
      string = string .. "- " .. path .. "\n"
    end
    string = string .. "\n"
  end
  return string
end

---@return Actions
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
      return M.tostring(t)
    end,
    __concat = function(t1, t2)
      return M.concat(t1, t2)
    end,
  })
  return new
end

return M
