return {
	"rebelot/heirline.nvim",
	event = "VeryLazy",
	config = function()
		local hls = require("frontend.status.heirline.hls")
		local comp = require("frontend.status.heirline.components")
		local conditions = require("heirline.conditions")
		local c = require("config.theme").colors

		hls.setup_highlights()

		local StatusLine = {
			comp.Mode,
			comp.Space,
			comp.FileName,
			comp.Git,
			comp.Align,
			comp.Diagnostics,
			comp.LspActive,
			comp.LspInactive,
			comp.Space,
			comp.FileIcon,
			comp.FileType,
			comp.FileFormat,
			comp.Space,
			comp.Ruler,
		}

		local InactiveStatusLine = {
			condition = function()
				return not conditions.is_active()
			end,
			{ provider = "%<%F", hl = { fg = c.comment, bg = c.black } },
			comp.Align,
		}

		require("heirline").setup({
			statusline = { StatusLine, InactiveStatusLine },
			opts = {
				disable_winbar_cb = function(args)
					return conditions.buffer_matches({
						buftype = { "nofile", "prompt", "help", "quickfix" },
						filetype = { "^git.*", "fugitive", "Trouble", "lazy", "mason" },
					}, args.buf)
				end,
			},
		})

		local group = vim.api.nvim_create_augroup("HeirlineHighlights", { clear = true })

		vim.api.nvim_create_autocmd("ColorScheme", {
			group = group,
			callback = function()
				hls.setup_highlights()
			end,
		})
	end,
}
