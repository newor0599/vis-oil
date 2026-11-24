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
- Icons

### Installation
With vis-plug
```lua
{ "newor0599/vis-oil", alias="oil" },
```

### Preview configuration
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

-- Show last modified as MM/DD/YYYY HH:MM
oil.options.attributes = {"%D %H:%M"}

-- Sort entries in option order
--   1. Sort directory first
--   2. Sort hidden entries last
--   3. Sort entry size by ascending order
oil.options.sort = { "directory", "hidden d", "size" }

-- Set custom info column separator
oil.options.separator = "╳ "
```

### Sort options
vis-oil sort entries by option order

| option    | description             |
| --------- | ----------------------- |
| modified  | sort by last modified   |
| size      | sort by file size       |
| name      | sort by file name       |
| hidden    | sort hidden entry first |
| directory | sort directory first    |

option with suffix `d` will operate in descending order

### Attribute option

| option       | description                       |
| ------------ | --------------------------------- |
| size         | show entry size by automatic unit |
| permissions  | show entry mode bit               |
| date         | show date in locale format        |
| filetype     | show entry filetype character     |
| user owner   | show entry's user owner           |
| group owner  | show entry's group owner          |
| B,KB,MB,GB.. | show size in specific unit        |
| *strftime*   | show time with custom strftime    |

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
