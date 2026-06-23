local AdapterScanner = require("backend.shared.AdapterScanner")
local linter_opts = { check_executable = true }

return {
	"mfussenegger/nvim-lint",
	ft = AdapterScanner:supported_filetypes("linter", linter_opts),

	config = function()
		local lint = require("lint")
		lint.linters_by_ft = AdapterScanner:by_filetype("linter", linter_opts)

		local group = vim.api.nvim_create_augroup("LinterWatch", { clear = true })

		vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter" }, {
			group = group,
			callback = function(event)
				local filetype = vim.bo[event.buf].filetype

				if filetype == "" or vim.bo[event.buf].buftype ~= "" then
					return
				end

				if not AdapterScanner:supports_filetype("linter", filetype, linter_opts) then
					return
				end

				lint.try_lint(nil, {
					ignore_errors = true,
				})
			end,
		})
	end,
}
