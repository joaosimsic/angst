local Keybinder = require("common.Keybinder")

local M = {}

M.setup = function()
	local move = require("frontend.move.move")
	local binder = Keybinder.new(nil, "MOVE")

	binder:map({ "x" }, "<A-j>", function()
		move.move_text_vertical("j")
	end, { desc = "Move text down" })

	binder:map({ "x" }, "<A-k>", function()
		move.move_text_vertical("k")
	end, { desc = "Move text up" })

	binder:map({ "x" }, "<A-h>", function()
		move.move_text_horizontal("h")
	end, { desc = "Move text to the left" })

	binder:map({ "x" }, "<A-l>", function()
		move.move_text_horizontal("l")
	end, { desc = "Move text to the right" })
end

return M
