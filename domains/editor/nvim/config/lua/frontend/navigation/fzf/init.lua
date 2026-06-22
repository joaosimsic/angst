return {
	"ibhagwan/fzf-lua",
	event = "VeryLazy",
	config = function()
		local fzf = require("fzf-lua")

		fzf.setup({
			fzf_colors = true,
			winopts = {
				width = 0.90,
				height = 0.92,
				preview = {
					hidden = "hidden",
					horizontal = "right:50%",
				},
			},
			keymap = {
				builtin = {
					["<Tab>"] = "toggle-preview",
				},
			},
			grep = {
				rg_opts = "--column --line-number --no-heading --color=always --smart-case --max-columns=4096 --hidden",
				rg_glob = true,
				glob_flag = "--glob",
				glob_separator = "%s",

				file_ignore_patterns = {
					"node_modules/",
					"dist/",
					"%.lock$",
				},
			},
		})

		fzf.register_ui_select()

		require("frontend.navigation.fzf.keys")
	end,
}
