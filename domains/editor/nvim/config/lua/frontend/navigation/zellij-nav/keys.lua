local Keybinder = require("common.Keybinder")

local M = {}

function M.setup()
	local move = require("frontend.navigation.zellij-nav.move")
	local binder = Keybinder.new(nil, "ZELLIJ_NAV")

	binder:nmap("<C-h>", function()
		move.left()
	end, "Navigate left")
	binder:nmap("<C-j>", function()
		move.down()
	end, "Navigate down")
	binder:nmap("<C-k>", function()
		move.up()
	end, "Navigate up")
	binder:nmap("<C-l>", function()
		move.right()
	end, "Navigate right")
end

return M
