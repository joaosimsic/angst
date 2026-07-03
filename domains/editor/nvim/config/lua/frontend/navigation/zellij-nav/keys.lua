local Keybinder = require("common.Keybinder")

local M = {}

local function terminal_escape()
	vim.api.nvim_feedkeys(
		vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true),
		"n",
		true
	)
end

local function tn(fn)
	return function()
		terminal_escape()
		fn()
	end
end

function M.setup()
	local move = require("frontend.navigation.zellij-nav.move")
	local binder = Keybinder.new(nil, "ZELLIJ_NAV")

	binder:nmap("<C-h>", move.left, { desc = "Navigate left" })
	binder:nmap("<C-j>", move.down, { desc = "Navigate down" })
	binder:nmap("<C-k>", move.up, { desc = "Navigate up" })
	binder:nmap("<C-l>", move.right, { desc = "Navigate right" })

	binder:tmap("<C-h>", tn(move.left), { desc = "Navigate left" })
	binder:tmap("<C-j>", tn(move.down), { desc = "Navigate down" })
	binder:tmap("<C-k>", tn(move.up), { desc = "Navigate up" })
	binder:tmap("<C-l>", tn(move.right), { desc = "Navigate right" })
end

return M
