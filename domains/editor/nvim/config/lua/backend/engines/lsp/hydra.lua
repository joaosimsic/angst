local Hydra = require("common.Hydra")

local M = {}

---@param bufnr number
---@return Hydra
function M.create_diagnostics(bufnr)
	return Hydra.new({
		name = "Diagnostic",
		enter = "<leader>d",
		heads = {
			{
				"j",
				function()
					vim.diagnostic.jump({ count = 1, wrap = false })
				end,
				"Next Diagnostic",
			},
			{
				"k",
				function()
					vim.diagnostic.jump({ count = -1, wrap = false })
				end,
				"Prev Diagnostic",
			},
			{ "l", vim.diagnostic.open_float, "Line Diagnostics" },
		},
	}, bufnr)
end

return M
