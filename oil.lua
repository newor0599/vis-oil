if not vis.communicate then
	vis:message("Oil Error: file operations requires vis communicate patch")
	return {}
end

Entry = require("vis-oil.entry")
Utils = require("vis-oil.utils")
Shell = require("vis-oil.shell")
Instance = require("vis-oil.instance")
---Main class for oil
---@class oil
oil = {
	DIR_COLOR = vis.ui:style_push("fore:#95AEC7,back:#1C2023"),
	SYM_COLOR = vis.ui:style_push("fore:#C7C795,back:#1C2023"),
	INSTANCE_EXIT_EVENT = "OIL_INSTANCE_EXIT",
	file_ids = 0,
	window_ids = 0,
	instances = {},
}

vis.events.subscribe(oil.INSTANCE_EXIT_EVENT, function(id)
	vis:info(id .. " instance ended")
end)

oil.options = {
	show_hidden = false,
}

function oil:make_window_id()
	self.window_ids = self.window_ids + 1
	return self.window_ids
end

function oil:make_file_id()
	self.file_ids = self.file_ids + 1
	return self.file_ids
end

---@param method? "current"|"horizontal"|"vertical" Start oil in current buffer/horizontally/vertically (default)
function oil:open(method)
	local window_id = "OIL\\ " .. tostring(self:make_window_id())
	if method == nil or method == "vertical" then
		method = "vertical"
		vis:command("vsplit " .. window_id)
	elseif method == "horizontal" then
		vis:command("split " .. window_id)
	elseif method == "current" then
		if vis.win.file.modified then
			vis:info("Save your changes first!")
			return
		end
	end

	local cwd = Shell.get_win_cwd()
	-- vis:message("Active window type: "..type(vis.win))
	local window = vis.win
	local instance = Instance.new(self, window, cwd)
	-- self.instances[id] = instance

	instance:insert_data()

	-- if instance.window.file.name == nil then
	-- 	vis:feedkeys("gg")
	-- end

	-- vis.events.subscribe(vis.events.INPUT, function(keys)
	-- 	if keys == "dd" then
	-- 		self.oil_window.file:snapshot()
	-- 	end
	-- end)
end

function oil.open_vertical(self)
	self:open()
end

function oil.open_horizontal(self)
	self:open("horizontal")
end

function oil.open_current(self)
	self:open("current")
end

return oil
