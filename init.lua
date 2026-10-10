require("vis")
Entry = require("vis-oil.entry")
Utils = require("vis-oil.utils")
Shell = require("vis-oil.shell")
if not vis.communicate then
	vis:message("Oil Error: file operations requires vis communicate patch")
	return {}
end

---@class options
options = {
	show_hidden = false,
}

---@class oil
---@field oil_window? vis.window
oil = {
	directory_lines = { -1, -1 },
	symlink_lines = {},
	DIR_COLOR = vis.ui:style_push("fore:#95AEC7,back:#1C2023"),
	SYM_COLOR = vis.ui:style_push("fore:#C7C795,back:#1C2023"),
	oil_window = nil,
	original_file_path = "",
	ids = 0,
}

---@param self oil
function oil.setup(self)
	vis.events.subscribe(vis.events.WIN_HIGHLIGHT, function()
		if self.oil_window then
			self.oil_window:style(self.DIR_COLOR, self.directory_lines["start"], self.directory_lines["end"])
		end
	end)

	vis.events.subscribe(vis.events.WIN_STATUS, function(_)
		if self.oil_window then
			self.oil_window:status("OIL")
		end
	end)

	vis.events.subscribe(vis.events.WIN_CLOSE, function(win)
		if win == self.oil_window then
			self.oil_window = nil
		end
	end)
end

function oil._insert_data(self, entries)
	local window_cursor = 0
	for _, entry in ipairs(entries) do
		if options["show_hidden"] or not entry["is_hidden"] then
			if entry["is_dir"] then
				self.directory_lines = { start = 0, ["end"] = window_cursor + #entry["display_name"] }
			end

			self.oil_window.file:insert(window_cursor, entry["display_name"])
			window_cursor = window_cursor + #entry["display_name"]

			self.oil_window.file:insert(window_cursor, "\n")
			window_cursor = window_cursor + 1
		end
	end
end

---@param method? "current"|"horizontal"|"vertical" Start oil in current buffer/horizontally/vertically (default)
function oil.open(self, method)
	if method == nil or method == "vertical" then
		method = "vertical"
		vis:command("vnew")
	elseif method == "horizontal" then
		vis:command("new")
	elseif method == "current" then
		if vis.win.file.modified then
			vis:info("Save your changes first!")
			return
		end
	end

	self.oil_window = vis.win
	-- self.oil_window.options.statusbar = false

	local cwd = Shell.get_win_cwd()
	local ls_out = Shell.get_ls(cwd)
	local entries = Utils.parse_ls(ls_out, cwd)

	self:_insert_data(entries)

	if self.oil_window.file.name == nil then
		vis:feedkeys("gg")
	end

	self.oil_window:map(vis.modes.NORMAL, "q", function()
		self.oil_window:close(true)
	end)

	self.oil_window:map(vis.modes.NORMAL, "<Enter>", function()
		vis:info("cool")
	end)

	self.oil_window:map(vis.modes.NORMAL, ".", function()
		options.show_hidden = not options.show_hidden
		self.oil_window:close(true)
		self.open()
		self.oil_window.file:delete({
			start = 0,
			finish = self.oil_window.file.size,
		})
	end)

	self.oil_window:map(vis.modes.NORMAL, "c", function()
		vis:info(cwd)
	end)

	vis.events.subscribe(vis.events.INPUT, function(keys)
		if keys == "dd" then
			self.oil_window.file:snapshot()
		end
	end)
end

function oil.open_vertical(self)
	self.open()
end

function oil.open_horizontal(self)
	self:open("horizontal")
end

function oil.open_current(self)
	self:open("current")
end
