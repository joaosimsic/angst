local function select_and_center(index)
	require("harpoon"):list():select(index)
	vim.cmd("normal! zz")
end

return {
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		keys = {
			{
				"<leader>a",
				function()
					require("harpoon"):list():add()
				end,
				desc = "Harpoon Add File",
				mode = "n",
			},
			{
				"<C-e>",
				function()
					local harpoon = require("harpoon")
					harpoon.ui:toggle_quick_menu(harpoon:list())
				end,
				desc = "Harpoon Toggle Menu",
				mode = "n",
			},
			{
				"<M-1>",
				function()
					select_and_center(1)
				end,
				desc = "Harpoon Navigate to File 1",
				mode = "n",
			},
			{
				"<M-2>",
				function()
					select_and_center(2)
				end,
				desc = "Harpoon Navigate to File 2",
				mode = "n",
			},
			{
				"<M-3>",
				function()
					select_and_center(3)
				end,
				desc = "Harpoon Navigate to File 3",
				mode = "n",
			},
			{
				"<M-4>",
				function()
					select_and_center(4)
				end,
				desc = "Harpoon Navigate to File 4",
				mode = "n",
			},
			{
				"<M-5>",
				function()
					select_and_center(5)
				end,
				desc = "Harpoon Navigate to File 5",
				mode = "n",
			},
			{
				"<M-6>",
				function()
					select_and_center(6)
				end,
				desc = "Harpoon Navigate to File 6",
				mode = "n",
			},
		},
		config = function()
			require("harpoon"):setup({
				settings = {
					save_on_toggle = false,
					sync_on_ui_close = true,
					key = function()
						return vim.uv.cwd() or vim.fn.getcwd()
					end,
				},
			})
		end,
	},
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.8",
		dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope-ui-select.nvim" },
		keys = {
			{
				"<leader>ff",
				function()
					require("telescope.builtin").find_files()
				end,
				desc = "Telescope find files",
			},
			{
				"<leader>fg",
				function()
					require("telescope.builtin").live_grep()
				end,
				desc = "Telescope live grep",
			},
			{
				"<leader>fb",
				function()
					require("telescope.builtin").buffers()
				end,
				desc = "Telescope buffers",
			},
			{
				"<leader>fo",
				function()
					require("telescope.builtin").oldfiles()
				end,
				desc = "Telescope recent files",
			},
			{
				"<leader>fh",
				function()
					require("telescope.builtin").help_tags()
				end,
				desc = "Telescope help tags",
			},
		},
		config = function()
			local actions_layout = require("telescope.actions.layout")

			require("telescope").setup({
				defaults = {
					preview = {
						hide_on_startup = true,
					},

					mappings = {
						i = {
							["<Tab>"] = actions_layout.toggle_preview,
						},
						n = {
							["<Tab>"] = actions_layout.toggle_preview,
						},
					},

					layout_strategy = "horizontal",

					layout_config = {
						width = 0.98,
						height = 0.92,

						horizontal = {
							preview_width = 0.6,
						},
					},

					file_ignore_patterns = {
						"node_modules/",
						"dist/",
						".git/",
						"build/",
						"target/",
						"public/",
						"%.lock",
					},

					vimgrep_arguments = {
						"rg",
						"--color=never",
						"--no-heading",
						"--with-filename",
						"--line-number",
						"--column",
						"--smart-case",

						"--hidden",
						"--no-ignore-vcs",

						"--glob=!.git/**",
						"--glob=!node_modules/**",
						"--glob=!dist/**",
						"--glob=!build/**",
						"--glob=!target/**",
					},
				},

				pickers = {
					find_files = {
						hidden = true,
						no_ignore = true,
						no_ignore_parent = true,
					},
				},

				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown({}),
					},
				},
			})

			require("telescope").load_extension("ui-select")
		end,
	},
	{
		"swaits/zellij-nav.nvim",
		lazy = true,
		event = "VeryLazy",
		keys = {
			{ "<A-h>", "<cmd>ZellijNavigateLeftTab<cr>", mode = "n", silent = true, desc = "Navigate left" },
			{ "<A-j>", "<cmd>ZellijNavigateDown<cr>", mode = "n", silent = true, desc = "Navigate down" },
			{ "<A-k>", "<cmd>ZellijNavigateUp<cr>", mode = "n", silent = true, desc = "Navigate up" },
			{ "<A-l>", "<cmd>ZellijNavigateRightTab<cr>", mode = "n", silent = true, desc = "Navigate right" },
		},
		cond = function()
			return vim.fn.executable("zellij") == 1 and vim.env.ZELLIJ ~= nil
		end,
		opts = {},
	},
}
