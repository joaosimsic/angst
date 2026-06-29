---@type Logger
local Logger = require("common.Logger")
---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"undo",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local logger = Logger.new("UNDO")
		local binder = Keybinder.new(nil, "UNDO")

		vim.cmd("packadd nvim.undotree")

		binder:nmap("<leader>u", function()
			require("undotree").open()

			local has_gitsigns, gitsigns = pcall(require, "gitsigns")

			if not has_gitsigns then
				logger:error(function()
					return "Missing gitsigns dependency"
				end)
			end

			gitsigns.toggle_linehl()
			gitsigns.toggle_word_diff()
		end, { desc = "toggle undotree with inline diff" })

		vim.opt.diffopt:append({
			"internal",
			"filler",
			"closeoff",
			"linematch:60",
			"algorithm:histogram",
		})
	end,
}
