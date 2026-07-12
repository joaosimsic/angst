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

		local palette = require("config.theme.palette").get()
		local p = palette.palette

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
				local is_nvim_active = conditions.is_active()
				local is_term_active = vim.g.terminal_focused ~= false
				self.is_active = is_nvim_active and is_term_active

				self.bg = utils.status_color(self, p.background.variant)
				self.fg = utils.status_color(self, p.accent.base)
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
			comp.DiagnosticsHistory,
			comp.LspActive,
			comp.LspInactive,
			comp.Anchor,
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
				always_update = function()
					return true
				end,
				disable_winbar_cb = function(args)
					return conditions.buffer_matches({
						buftype = { "nofile", "prompt", "help", "quickfix" },
						filetype = { "^git.*", "fugitive", "Trouble", "lazy", "mason" },
					}, args.buf)
				end,
			},
		})

		local group = vim.api.nvim_create_augroup("Heirline", { clear = true })

		vim.g.terminal_focused = true

		vim.api.nvim_create_autocmd("FocusGained", {
			group = group,
			callback = function()
				vim.g.terminal_focused = true
				require("heirline").statusline:broadcast(function(c)
					c._win_cache = nil
				end)
				vim.cmd("redrawstatus!")
			end,
		})

		vim.api.nvim_create_autocmd("FocusLost", {
			group = group,
			callback = function()
				vim.g.terminal_focused = false
				require("heirline").statusline:broadcast(function(c)
					c._win_cache = nil
				end)
				vim.cmd("redrawstatus!")
			end,
		})

		vim.api.nvim_create_autocmd("ColorScheme", {
			group = group,
			callback = function()
				hls.setup_highlights()
			end,
		})

		vim.api.nvim_create_autocmd("TermClose", {
			group = group,
			callback = function()
				if vim.bo.filetype == "yazi" then
					local win = vim.api.nvim_get_current_win()
					if vim.api.nvim_win_is_valid(win) then
						vim.api.nvim_set_current_win(win)
						vim.cmd("close!")
					end
				end
				require("heirline").statusline:broadcast(function(c)
					c._win_cache = nil
				end)
				vim.cmd("redrawstatus!")
			end,
		})

		vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "WinLeave" }, {
			group = group,
			callback = function()
				require("heirline").statusline:broadcast(function(c)
					c._win_cache = nil
				end)
				vim.cmd("redrawstatus!")
			end,
		})

		local binder = Keybinder.new(nil, "HEIRLINE")
		binder:map({ "i", "c", "v" }, "<C-c>", function()
			local keys = vim.api.nvim_replace_termcodes("<C-c><Cmd>redrawstatus<CR>", true, false, true)
			vim.api.nvim_feedkeys(keys, "n", false)
		end, { silent = true })
	end,
}
