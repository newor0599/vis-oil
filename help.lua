local M = {}
M.message = [[
Commands

[open]
Opens oil vertically by default

- buffer
Open oil at current buffer

- v(ertical)
Open oil vertically

- h(orizontal)
Open oil horizontally

# Example
:oil open buffer     # open at current buffer
:oil open v          # open vertically
:oil open horizontal # open horizontally
:oil open            # open vertically

[debug]
- window
Print the data of the window

[help]
Print this message
]]
return M
