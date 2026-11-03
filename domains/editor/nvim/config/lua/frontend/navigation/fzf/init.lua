---@type Plugin
return {
	"ibhagwan/fzf-lua",
	lazy = false,
	config = function()
		local fzf = require("fzf-lua")
		local fzf_keys = require("frontend.navigation.fzf.keys")
		local SearchIgnore = require("common.SearchIgnore")

		fzf.setup({
			fzf_colors = true,
			file_ignore_patterns = SearchIgnore.fzf_ignore_patterns(),
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
			actions = {
				files = {
					["default"] = fzf.actions.file_edit,
					["ctrl-v"] = fzf.actions.file_vsplit,
					["ctrl-z"] = fzf.actions.file_split,
				},
			},
			grep = {
				rg_opts = SearchIgnore.rg_opts(),
				rg_glob = true,
				glob_flag = "--glob",
				glob_separator = "%s",
			},
		})

		fzf.register_ui_select()
		fzf_keys.setup()
	end,
}
