---@class SourceDestination
---@field source string
---@field destination string
return {
  new = function(src, dst)
    return { source = src, destination = dst }
  end,
}
