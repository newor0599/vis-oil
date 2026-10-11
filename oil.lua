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
	instances = {},
}

oil.options = {
	show_hidden = false,
}

function oil:make_file_id()
	self.file_ids = self.file_ids + 1
	return self.file_ids
end

---@param method? "current"|"horizontal"|"vertical" Start oil in current buffer/horizontally/vertically (default)
function oil:open(method)
	if method == nil or method == "vertical" then
		method = "vertical"
		vis:command("vnew")
	elseif method == "horizontal" then
		vis:command("split")
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
