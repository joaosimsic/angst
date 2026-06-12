local shared_highlights = require("config.colors")
require("config.theme")

return {
	-- {
	-- 	"scottmckendry/cyberdream.nvim",
	-- 	lazy = false,
	-- 	priority = 1000,
	-- 	config = function()
	-- 		require("cyberdream").setup()
	-- 		vim.cmd("colorscheme cyberdream")
	-- 	end,
	-- },
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			local c = require("config.theme").colors
			local theme = {
				normal = {
					a = { fg = c.black, bg = c.base, gui = "bold" },
					b = { fg = c.base, bg = c.surface },
					c = { fg = c.base, bg = c.surface },
				},
				insert = {
					a = { fg = c.black, bg = c.bright, gui = "bold" },
					b = { fg = c.bright, bg = c.surface },
					c = { fg = c.base, bg = c.surface },
				},
				visual = {
					a = { fg = c.black, bg = c.yellow, gui = "bold" },
					b = { fg = c.yellow, bg = c.surface },
					c = { fg = c.base, bg = c.surface },
				},
				replace = {
					a = { fg = c.black, bg = c.red, gui = "bold" },
					b = { fg = c.red, bg = c.surface },
					c = { fg = c.base, bg = c.surface },
				},
				command = {
					a = { fg = c.black, bg = c.cyan, gui = "bold" },
					b = { fg = c.cyan, bg = c.surface },
					c = { fg = c.base, bg = c.surface },
				},
				inactive = {
					a = { fg = c.comment, bg = c.surface },
					b = { fg = c.comment, bg = c.surface },
					c = { fg = c.comment, bg = c.surface },
				},
			}
			require("lualine").setup({
				options = { theme = theme },
				sections = { lualine_z = { "location" } },
			})
		end,
	},
	{
		"xiyaowong/transparent.nvim",
		lazy = false,
		config = function()
			require("transparent").setup({
				exclude_groups = { "CursorLine" },
			})
			vim.cmd("TransparentEnable")
		end,
	},
	{
		"norcalli/nvim-colorizer.lua",
		config = function()
			require("colorizer").setup()
		end,
	},
	{
		"HiPhish/rainbow-delimiters.nvim",
		dependencies = { "lukas-reineke/indent-blankline.nvim" },
		config = function()
			local rainbow_delimiters = require("rainbow-delimiters")

			require("rainbow-delimiters.setup").setup({
				strategy = {
					[""] = rainbow_delimiters.strategy["global"],
					vim = rainbow_delimiters.strategy["local"],
				},
				query = {
					[""] = "rainbow-delimiters",
					lua = "rainbow-blocks",
				},
				priority = {
					[""] = 110,
					lua = 210,
				},
				highlight = shared_highlights.groups,
			})
		end,
	},
}
