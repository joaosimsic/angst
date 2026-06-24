---@type Plugin
return {
	"rebelot/heirline.nvim",
	event = "VeryLazy",
	config = function()
		local hls = require("frontend.status.heirline.hls")
		local comp = require("frontend.status.heirline.components")
		local conditions = require("heirline.conditions")

		---@type ThemePalette
		local p = require("config.theme.palette").get()

		hls.setup_highlights()

		---@type HeirlineComponent
		local LeftSideMode = {
			fallthrough = false,
			comp.Hydra,
			comp.Mode,
		}

		---@type HeirlineComponent
		local StatusLine = {
			LeftSideMode,
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

		---@type HeirlineComponent
		local InactiveStatusLine = {
			condition = function()
				return not conditions.is_active()
			end,
			{ provider = "%<%F", hl = { fg = p.comment, bg = p.black } },
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
