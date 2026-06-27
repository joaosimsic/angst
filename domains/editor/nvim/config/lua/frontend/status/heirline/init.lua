---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"rebelot/heirline.nvim",
	event = "VeryLazy",
	config = function()
		local hls = require("frontend.status.heirline.hls")
		local comp = require("frontend.status.heirline.components")
		local utils = require("frontend.status.heirline.utils")
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
			init = function(self)
				self.is_active = conditions.is_active()
				vim.g.heirline_statusline_is_active = self.is_active

				self.bg = utils.status_color(self, p.surface)
				self.fg = utils.status_color(self, p.base)
			end,

			hl = function(self)
				return { fg = self.fg, bg = self.bg }
			end,

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

		require("heirline").setup({
			statusline = StatusLine,
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

		local binder = Keybinder.new(nil, "HEIRLINE")
		binder:map({ "i", "c" }, "<C-c>", function()
			local keys = vim.api.nvim_replace_termcodes("<C-c><Cmd>redrawstatus<CR>", true, false, true)
			vim.api.nvim_feedkeys(keys, "n", false)
		end, { silent = true })
	end,
}
