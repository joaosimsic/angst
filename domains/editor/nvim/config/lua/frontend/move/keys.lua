local Keybinder = require("common.Keybinder")

local M = {}

function M.setup()
	local move = require("frontend.move.move")
	local binder = Keybinder.new(nil, "MOVE")

	binder:vmap("<A-j>", function()
		move.move_text_vertical("j")
	end, "Move text down")

	binder:vmap("<A-k>", function()
		move.move_text_vertical("k")
	end, "Move text up")

	binder:vmap("<A-h>", function()
		move.move_text_horizontal("h")
	end, "Move text to the left")

	binder:vmap("<A-l>", function()
		move.move_text_horizontal("l")
	end, "Move text to the right")
end

return M
