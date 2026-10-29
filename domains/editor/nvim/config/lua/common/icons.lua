---@class DiagnosticIcons
---@field error string
---@field warn string
---@field info string
---@field hint string

---@class Icons
---@field diagnostics DiagnosticIcons

---@type Icons
local M = {
	diagnostics = {
		error = "󰅚",
		warn = "󰀪",
		info = "󰋽",
		hint = "󰌶",
	},
}

return M
