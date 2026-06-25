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

		local function apply_dark_filter(hex, factor)
			hex = hex:gsub("#", "")
			if #hex ~= 6 then
				return "#000000"
			end

			local r = tonumber(hex:sub(1, 2), 16)
			local g = tonumber(hex:sub(3, 4), 16)
			local b = tonumber(hex:sub(5, 6), 16)

			r = math.floor(r * factor)
			g = math.floor(g * factor)
			b = math.floor(b * factor)

			return string.format("#%02x%02x%02x", r, g, b)
		end

		---@type HeirlineComponent
		local LeftSideMode = {
			fallthrough = false,
			comp.Hydra,
			comp.Mode,
		}

		---@type HeirlineComponent
		local StatusLine = {
			init = function(self)
				if conditions.is_active() then
					self.bg = p.surface
					self.fg = p.base
				else
					self.bg = apply_dark_filter(p.surface, 0.65)
					self.fg = p.comment
				end
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
	end,
}
