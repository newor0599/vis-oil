---One window one instance of oil
---But under same oil class to
---keep track of ids

---@class instance
---@field oil oil
---@field cwd string
---@field original_file string
---@field window vis.window
---@field directory_lines vis.range
---@field symlink_lines vis.range
instance = {}
instance.__index = instance

function instance:insert_data()
	local ls_out = Shell.get_ls(self.cwd)
	local entries = Utils.parse_ls(ls_out, self.cwd)
	local window_cursor = 0
	for _, entry in ipairs(entries) do
		if self.oil.options["show_hidden"] or not entry["is_hidden"] then
			if entry["is_dir"] then
				self.directory_lines.finish = window_cursor
					+ #entry["display_name"]
			end

			self.window.file:insert(window_cursor, entry["display_name"])
			window_cursor = window_cursor + #entry["display_name"]

			self.window.file:insert(window_cursor, "\n")
			window_cursor = window_cursor + 1
		end
	end
	self.window:draw()
end

function instance:statusbar(win)
	if self.window == win then
    self.window:status("Oil")
	end
end

function instance:highlight(win)
	if self.window == win then
		self.window:style(
			self.oil.DIR_COLOR,
			self.directory_lines.start,
			self.directory_lines.finish
		)
	end
end

function instance:close(win)
	if self.window == win then
		self.window = nil
		vis.events.unsubscribe(vis.events.WIN_STATUS, self.statusbar_handler)
		vis.events.unsubscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)
	end
end

function instance:init()
	self.statusbar_handler = function(win)
		self:statusbar(win)
	end

	self.highlight_handler = function(win)
		self:highlight(win)
	end

	self.close_handler = function(win)
		self:close(win)
	end

	vis.events.subscribe(vis.events.WIN_HIGHLIGHT, self.highlight_handler)

	vis.events.subscribe(vis.events.WIN_STATUS, self.statusbar_handler)

	vis.events.subscribe(vis.events.WIN_CLOSE, self.close_handler)

	self.window:map(vis.modes.NORMAL, "q", function()
		if self.window then
			local id = self.window.file.name
			self.window:close(true)
			self:close()
			vis.events.emit(self.oil.INSTANCE_EXIT_EVENT, id)
		end
	end)

	self.window:map(vis.modes.NORMAL, "<Enter>", function()
		vis:info("cool")
	end)

	self.window:map(vis.modes.NORMAL, "c", function()
		vis:info(self.cwd)
	end)
end

---@param oil oil Main class
---@param window vis.window A designated window to start a new instance
---@param cwd string Start a new instance at a given working directory
function instance.new(oil, window, cwd)
	local new = {
		oil = oil,
		cwd = cwd,
		original_file = nil,
		window = window,
		directory_lines = { start = 0, finish = 1 },
		symlink_lines = { start = 0, finish = 0 },
	}
	setmetatable(new, { __index = instance })

	new:init()

	return new
end

return instance
