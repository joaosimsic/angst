local Keybinder = require("common.Keybinder")

local M = {}

function M.setup()
	local move = require("frontend.navigation.zellij-nav.move")
	local binder = Keybinder.new(nil, "ZELLIJ_NAV")

	binder:nmap("<C-h>", move.left, "Navigate left")
	binder:nmap("<C-j>", move.down, "Navigate down")
	binder:nmap("<C-k>", move.up, "Navigate up")
	binder:nmap("<C-l>", move.right, "Navigate right")
end

return M
