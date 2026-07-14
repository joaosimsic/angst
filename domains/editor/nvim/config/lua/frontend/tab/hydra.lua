---@type Hydra
local Hydra = require("common.Hydra")
---@type Logger
local Logger = require("common.Logger")

local M = {}

local function goto_tab(n)
	return function()
		vim.cmd(n .. "tabnext")
	end
end

function M.setup()
	local logger = Logger.new("TAB:HYDRA")

	Hydra.new({
		name = "Tab",
		fg_color = "blue_bright",
		bg_color = "black",
		enter = "<leader>t",
		logger = logger,
		heads = {
			{ "h", function() vim.cmd("tabprev") end,                    "Previous tab" },
			{ "l", function() vim.cmd("tabnext") end,                    "Next tab" },
			{ "H", function() vim.cmd("tabmove -1") end,                 "Move tab left" },
			{ "L", function() vim.cmd("tabmove +1") end,                 "Move tab right" },
			{ "n", function() vim.cmd("tabnew") end,                     "New tab" },
			{ "x", function() vim.cmd("tabclose") end,                   "Kill tab" },
			{ "1", goto_tab(1),                                          "Tab 1" },
			{ "2", goto_tab(2),                                          "Tab 2" },
			{ "3", goto_tab(3),                                          "Tab 3" },
			{ "4", goto_tab(4),                                          "Tab 4" },
			{ "5", goto_tab(5),                                          "Tab 5" },
			{ "6", goto_tab(6),                                          "Tab 6" },
			{ "7", goto_tab(7),                                          "Tab 7" },
			{ "8", goto_tab(8),                                          "Tab 8" },
			{ "9", goto_tab(9),                                          "Tab 9" },
			{ "=", function() vim.cmd("tablast") end,                    "Last tab" },
		},
		exit_keys = { "<Esc>", "<C-c>" },
	})
end

return M
