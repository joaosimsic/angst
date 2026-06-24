---@type Plugin
return {
	"ibhagwan/fzf-lua",
	event = "VeryLazy",
	config = function()
		local fzf = require("fzf-lua")
		local fzf_keys = require("frontend.navigation.fzf.keys")

		fzf.setup({
			fzf_colors = true,
			winopts = {
				width = 0.90,
				height = 0.92,
				preview = {
					hidden = "hidden",
					horizontal = "right:50%",
				},

				on_create = function()
					fzf_keys.on_picker_create()
				end,
			},
			keymap = {
				builtin = {
					["<Tab>"] = "toggle-preview",
				},
				fzf = {
					["ctrl-j"] = "down",
					["ctrl-k"] = "up",
					["ctrl-d"] = "half-page-down",
					["ctrl-u"] = "half-page-up",
          ["ctrl-c"] = "unix-line-discard+abort",
				},
			},
			grep = {
				rg_opts = "--column --line-number --no-heading --color=always --smart-case --max-columns=4096 --hidden",
				rg_glob = true,
				glob_flag = "--glob",
				glob_separator = "%s",
				file_ignore_patterns = { "node_modules/", "dist/", "%.lock$", "target/", "vendor/" },
			},
		})

		fzf.register_ui_select()
		fzf_keys.setup()
	end,
}
