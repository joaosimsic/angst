---@type Plugin
return {
	"diagnostics",
	virtual = true,
	lazy = false,
	config = function()
		local icons = require("common.icons")

		vim.diagnostic.config({
			virtual_text = false,
			virtual_lines = {
				current_line = true,
			},
			severity_sort = true,
			float = { border = "none" },
			update_in_insert = false,
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = icons.error,
					[vim.diagnostic.severity.WARN] = icons.warn,
					[vim.diagnostic.severity.INFO] = icons.info,
					[vim.diagnostic.severity.HINT] = icons.hint,
				},
			},
		})
	end,
}
