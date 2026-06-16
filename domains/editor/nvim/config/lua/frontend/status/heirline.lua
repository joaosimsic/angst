local c = require("config.theme").colors

local mode_colors = {
	n = { fg = c.black, bg = c.base, label = "NORMAL" },
	no = { fg = c.black, bg = c.base, label = "NORMAL" },
	i = { fg = c.black, bg = c.bright, label = "INSERT" },
	v = { fg = c.black, bg = c.yellow, label = "VISUAL" },
	V = { fg = c.black, bg = c.yellow, label = "V-LINE" },
	["\22"] = { fg = c.black, bg = c.yellow, label = "V-BLOCK" },
	s = { fg = c.black, bg = c.yellow, label = "SELECT" },
	S = { fg = c.black, bg = c.yellow, label = "S-LINE" },
	["\19"] = { fg = c.black, bg = c.yellow, label = "S-BLOCK" },
	r = { fg = c.black, bg = c.red, label = "REPLACE" },
	R = { fg = c.black, bg = c.red, label = "REPLACE" },
	c = { fg = c.black, bg = c.cyan, label = "COMMAND" },
	t = { fg = c.black, bg = c.cyan, label = "TERMINAL" },
}

local mode_fallback = { fg = c.base, bg = c.surface, label = "UNKNOWN" }

local function mode_data()
	return mode_colors[vim.fn.mode()] or mode_fallback
end

local function hl(name, opts)
	vim.api.nvim_set_hl(0, name, opts)
end

local function setup_highlights()
	hl("HeirlineModeNormal", { fg = c.black, bg = c.base, bold = true })
	hl("HeirlineModeInsert", { fg = c.black, bg = c.bright, bold = true })
	hl("HeirlineModeVisual", { fg = c.black, bg = c.yellow, bold = true })
	hl("HeirlineModeReplace", { fg = c.black, bg = c.red, bold = true })
	hl("HeirlineModeCommand", { fg = c.black, bg = c.cyan, bold = true })
	hl("HeirlineModeTerminal", { fg = c.black, bg = c.cyan, bold = true })
	hl("HeirlineModeUnknown", { fg = c.base, bg = c.surface, bold = true })

	hl("HeirlineSurface", { fg = c.base, bg = c.surface })
	hl("HeirlineSurfaceBold", { fg = c.bright, bg = c.surface, bold = true })
	hl("HeirlineBlack", { fg = c.base, bg = c.black })
	hl("HeirlineBlackBright", { fg = c.bright, bg = c.black })

	hl("HeirlineGit", { fg = c.bright, bg = c.surface })
	hl("HeirlineGitAdd", { fg = c.green, bg = c.surface })
	hl("HeirlineGitChange", { fg = c.yellow, bg = c.surface })
	hl("HeirlineGitDelete", { fg = c.red, bg = c.surface })

	hl("HeirlineDiagnosticError", { fg = c.red, bg = c.surface })
	hl("HeirlineDiagnosticWarn", { fg = c.yellow, bg = c.surface })
	hl("HeirlineDiagnosticInfo", { fg = c.blue, bg = c.surface })
	hl("HeirlineDiagnosticHint", { fg = c.cyan, bg = c.surface })

	hl("HeirlineLspActive", { fg = c.green, bg = c.surface })
	hl("HeirlineLspInactive", { fg = c.comment, bg = c.surface })

	hl("HeirlinePosition", { fg = c.black, bg = c.dim, bold = true })
end

return {
	"rebelot/heirline.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"lewis6991/gitsigns.nvim",
	},
	event = "VeryLazy",
	config = function()
		setup_highlights()

		local conditions = require("heirline.conditions")

		local Align = { provider = "%=" }
		local Space = { provider = " " }

		local Mode = {
			init = function(self)
				self.mode = mode_data()
			end,
			hl = function()
				local name_map = {
					n = "HeirlineModeNormal",
					no = "HeirlineModeNormal",
					i = "HeirlineModeInsert",
					v = "HeirlineModeVisual",
					V = "HeirlineModeVisual",
					["\22"] = "HeirlineModeVisual",
					s = "HeirlineModeVisual",
					S = "HeirlineModeVisual",
					["\19"] = "HeirlineModeVisual",
					r = "HeirlineModeReplace",
					R = "HeirlineModeReplace",
					c = "HeirlineModeCommand",
					t = "HeirlineModeTerminal",
				}
				return name_map[vim.fn.mode()] or "HeirlineModeUnknown"
			end,
			{
				provider = function(self)
					return " " .. self.mode.label .. " "
				end,
			},
		}

		local FileIcon = {
			init = function(self)
				local filename = self.filename
				local extension = vim.fn.fnamemodify(filename, ":e")
				self.icon, self.icon_color =
					require("nvim-web-devicons").get_icon_color(filename, extension, { default = true })
			end,
			hl = function(self)
				return { fg = self.icon_color, bg = c.surface }
			end,
			provider = function(self)
				return self.icon and (self.icon .. " ") or ""
			end,
		}

		local FileName = {
			provider = function(self)
				local filename = vim.fn.fnamemodify(self.filename, ":t")
				if filename == "" then
					return "[No Name]"
				end
				return filename
			end,
			hl = { fg = c.bright, bg = c.surface, bold = true },
		}

		local FileFlags = {
			{
				condition = function()
					return vim.bo.modified
				end,
				provider = " +",
				hl = { fg = c.green, bg = c.surface },
			},
			{
				condition = function()
					return not vim.bo.modifiable or vim.bo.readonly
				end,
				provider = " -",
				hl = { fg = c.red, bg = c.surface },
			},
		}

		local FileNameBlock = {
			init = function(self)
				self.filename = vim.api.nvim_buf_get_name(0)
			end,
			{ provider = " ", hl = { bg = c.surface } },
			FileIcon,
			FileName,
			FileFlags,
			{ provider = " ", hl = { bg = c.surface } },
		}

		local Git = {
			condition = function()
				return conditions.is_git_repo() and vim.b.gitsigns_status_dict ~= nil
			end,
			init = function(self)
				self.status_dict = vim.b.gitsigns_status_dict or {}
				self.has_changes = (self.status_dict.added or 0) ~= 0
					or (self.status_dict.removed or 0) ~= 0
					or (self.status_dict.changed or 0) ~= 0
			end,
			hl = { bg = c.surface },
			{ provider = " ", hl = { bg = c.surface } },
			{
				provider = function(self)
					return " " .. self.status_dict.head
				end,
				hl = "HeirlineGit",
			},
			{
				condition = function(self)
					return self.has_changes
				end,
				provider = " ",
			},
			{
				provider = function(self)
					local count = self.status_dict.added or 0
					return count > 0 and ("+" .. count) or ""
				end,
				hl = "HeirlineGitAdd",
			},
			{
				provider = function(self)
					local count = self.status_dict.changed or 0
					return count > 0 and ("~" .. count) or ""
				end,
				hl = "HeirlineGitChange",
			},
			{
				provider = function(self)
					local count = self.status_dict.removed or 0
					return count > 0 and ("-" .. count) or ""
				end,
				hl = "HeirlineGitDelete",
			},
			{ provider = " ", hl = { bg = c.surface } },
		}

		local Diagnostics = {
			condition = conditions.has_diagnostics,
			static = {
				error_icon = "ﰸ ",
				warn_icon = " ",
				info_icon = " ",
				hint_icon = " ",
			},
			init = function(self)
				self.errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
				self.warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
				self.hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
				self.info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
				self.total = self.errors + self.warnings + self.hints + self.info
			end,
			update = { "DiagnosticChanged", "BufEnter" },
			hl = { bg = c.surface },
			{ provider = " ", hl = { bg = c.surface } },
			{
				provider = function(self)
					return self.errors > 0 and (self.error_icon .. self.errors) or ""
				end,
				hl = "HeirlineDiagnosticError",
			},
			{
				provider = function(self)
					return self.warnings > 0 and (self.warn_icon .. self.warnings) or ""
				end,
				hl = "HeirlineDiagnosticWarn",
			},
			{
				provider = function(self)
					return self.info > 0 and (self.info_icon .. self.info) or ""
				end,
				hl = "HeirlineDiagnosticInfo",
			},
			{
				provider = function(self)
					return self.hints > 0 and (self.hint_icon .. self.hints) or ""
				end,
				hl = "HeirlineDiagnosticHint",
			},
			{ provider = " ", hl = { bg = c.surface } },
		}

		local LspActive = {
			condition = conditions.lsp_attached,
			update = { "LspAttach", "LspDetach" },
			provider = "●",
			hl = "HeirlineLspActive",
		}

		local LspInactive = {
			condition = function()
				return not conditions.lsp_attached()
			end,
			provider = "●",
			hl = "HeirlineLspInactive",
		}

		local FileType = {
			provider = function()
				local ft = vim.bo.filetype
				return ft ~= "" and string.format(" %s ", ft) or ""
			end,
			hl = "HeirlineSurfaceBold",
		}

		local FileEncoding = {
			provider = function()
				local enc = (vim.bo.fenc ~= "" and vim.bo.fenc) or vim.o.enc
				return string.format(" %s ", enc:upper())
			end,
			hl = "HeirlineSurface",
		}

		local FileFormat = {
			provider = function()
				local fmt = vim.bo.fileformat
				return string.format(" %s ", fmt:upper())
			end,
			hl = "HeirlineSurface",
		}

		local Ruler = {
			provider = " %l:%c %P ",
			hl = "HeirlinePosition",
		}

		local StatusLine = {
			Mode,
			Space,
			FileNameBlock,
			Space,
			Git,
			Align,
			Diagnostics,
			Space,
			LspActive,
			LspInactive,
			Space,
			FileType,
			FileEncoding,
			FileFormat,
			Ruler,
		}

		local InactiveStatusLine = {
			condition = function()
				return not conditions.is_active()
			end,
			{ provider = "%<%F", hl = { fg = c.comment, bg = c.black } },
			Align,
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

		vim.api.nvim_create_autocmd("ColorScheme", {
			callback = setup_highlights,
		})
	end,
}
