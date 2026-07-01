---@type Plugin
return {
	"HiPhish/rainbow-delimiters.nvim",
	ft = require("backend.shared.AdapterScanner"):supported_filetypes("treesitter", { check_executable = false }),
	config = function()
		local rainbow_delimiters = require("rainbow-delimiters")

		vim.g.rainbow_delimiters = {
			strategy = {
				[""] = rainbow_delimiters.strategy["global"],
			},
			query = {
				[""] = "rainbow-delimiters",
			},
			highlight = {
				"RainbowDelimiter1",
				"RainbowDelimiter2",
				"RainbowDelimiter3",
				"RainbowDelimiter4",
				"RainbowDelimiter5",
			},
		}

		local ok, colors_mod = pcall(require, "config.theme.colors")
		if not ok then
			return
		end
		local rainbow = colors_mod.get().rainbow

		local semantic_colors = {
			RainbowDelimiter1 = { fg = rainbow[1] },
			RainbowDelimiter2 = { fg = rainbow[2] },
			RainbowDelimiter3 = { fg = rainbow[3] },
			RainbowDelimiter4 = { fg = rainbow[4] },
			RainbowDelimiter5 = { fg = rainbow[5] },
		}

		for hl_group, opts in pairs(semantic_colors) do
			vim.api.nvim_set_hl(0, hl_group, opts)
		end
	end,
}
