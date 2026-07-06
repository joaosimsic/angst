---@type Plugin
return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },

	config = function()
		local AdapterScanner = require("backend.shared.AdapterScanner")
		local linter_opts = { check_executable = true }
		local lint = require("lint")
		lint.linters_by_ft = AdapterScanner:by_filetype("linter", linter_opts)

		local clippy = lint.linters.clippy
		if clippy then
			clippy.ignore_exitcode = true
		end

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
