local M = {}
M.message = [[
Commands

[open]
- buffer
Open oil at current buffer

- v(ertical)
Open oil vertically

- h(orizontal)
Open oil horizontally

# Example
:oil open buffer
:oil open v
:oil open horizontal

[debug]
- window
Print the data of the window

[help]
Print this message
]]
return M
