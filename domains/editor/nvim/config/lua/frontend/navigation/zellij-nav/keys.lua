local Keybinder = require("common.Keybinder")

local M = {}

function M.setup()
	local move = require("frontend.navigation.zellij-nav.move")
	local binder = Keybinder.new(nil, "ZELLIJ_NAV")

	binder:nmap("<C-h>", move.left, { desc = "Navigate left" })
	binder:nmap("<C-j>", move.down, { desc = "Navigate down" })
	binder:nmap("<C-k>", move.up, { desc = "Navigate up" })
	binder:nmap("<C-l>", move.right, { desc = "Navigate right" })
end

return M
