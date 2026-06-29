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

		local ok, palette_mod = pcall(require, "config.theme.palette")
		if not ok then
			return
		end
		local p = palette_mod.get()

		local semantic_colors = {
			RainbowDelimiter1 = { fg = p.accent },
			RainbowDelimiter2 = { fg = p.subtle },
			RainbowDelimiter3 = { fg = p.bright },
			RainbowDelimiter4 = { fg = p.base },
			RainbowDelimiter5 = { fg = p.cyan_bright },
		}

		for hl_group, opts in pairs(semantic_colors) do
			vim.api.nvim_set_hl(0, hl_group, opts)
		end
	end,
}
