# vis-oil

> ⚠️ Mostly stable, still hunting for bugs and security issues.

> ⚠️ Only tested on Linux (GNU) , not on other posix system

> ⚠️ There is a possible security vulnerebility of **command injection** attack, BEWARE!

![preview image](preview.png)

An [`oil.nvim`](https://github.com/stevearc/oil.nvim)-inspired file manager
plugin for the [Vis](https://github.com/martanne/vis) editor.

Edit your filesystem like a text buffer.

### Planned
- Full posix system support
- Sort (creation date, name, size, last modified)
- Icons
- Show file information (size, creation date, last modified, permissions)

### Installation
With vis-plug
```lua
{ "newor0599/vis-oil", alias="oil" },
```

### Configuration
```lua
-- Initialize default configuration
oil()

-- Show hidden files
oil.options.show_hidden = true

-- Map <Space>e to open oil in current buffer
oil:map_open_buffer(" e")

-- Map <Space>vv to open oil in a new vertical window
oil:map_open_vertical(" vv")

-- Map <Space>hh to open oil in a new horizontal window
oil:map_open_horizontal(" hh")
```

### Command usage
```lua
-- open oil at current buffer
:oil open_buffer

-- open oil vertically
:oil open_vertical

-- open oil horizontally
:oil open_horizontal

-- show help menu
:oil help
```

### Contribution
- Pull request for new feature or issues are welcome!
- Report bugs as an issue
