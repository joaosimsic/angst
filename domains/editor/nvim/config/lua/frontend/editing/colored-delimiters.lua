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

		local ok, pal = pcall(require, "config.theme.palette")
		if not ok then
			return
		end
		local p = pal.get().palette
		local rainbow = { p.accent.base, p.accent.base, p.foreground.variant, p.foreground.base, p.surface.base }

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
