local Hydra = require("common.Hydra")

-- BEFORE U WANT TO REFAC, THIS IS TO PREVENT
-- INVALID DIAGNOSTIC TO JUMP MESSAGE SPAM
---@param bufnr integer
---@return boolean, boolean
local function check_edges(bufnr)
	local diagnostics = vim.diagnostic.get(bufnr)
	if #diagnostics == 0 then
		return false, false
	end

	table.sort(diagnostics, function(a, b)
		return a.lnum < b.lnum
	end)

	local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
	local first_diag_line = diagnostics[1].lnum
	local last_diag_line = diagnostics[#diagnostics].lnum

	return current_line > first_diag_line, current_line < last_diag_line
end

local M = {}

---@param bufnr number
---@return Hydra
function M.create_diagnostics(bufnr)
	return Hydra.new({
		name = "Diagnostic",
		---@type ThemePaletteKey
		fg_color = "red",
		---@type ThemePaletteKey
		bg_color = "black",
		enter = "<leader>d",
		heads = {
			{
				"j",
				function()
					local _, can_go_down = check_edges(bufnr)
					if can_go_down then
						vim.diagnostic.jump({ count = 1, wrap = false })
					end
				end,
				"Next Diagnostic",
			},
			{
				"k",
				function()
					local can_go_up, _ = check_edges(bufnr)
					if can_go_up then
						vim.diagnostic.jump({ count = -1, wrap = false })
					end
				end,
				"Prev Diagnostic",
			},
			{ "l", vim.diagnostic.open_float, "Line Diagnostics" },
		},
	}, bufnr)
end

return M
