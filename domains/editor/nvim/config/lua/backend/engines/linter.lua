return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },

	config = function()
		local lint = require("lint")
		local scan_adapters = require("backend.shared.scan_adapters")

		local linters_by_ft = {}

		for linter_name, opts in pairs(scan_adapters("linter", { check_executable = true })) do
			for _, ft in ipairs(opts.filetypes or {}) do
				linters_by_ft[ft] = linters_by_ft[ft] or {}
				table.insert(linters_by_ft[ft], linter_name)
			end
		end

		lint.linters_by_ft = linters_by_ft

		local group = vim.api.nvim_create_augroup("LinterWatch", { clear = true })

		vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
			group = group,
			callback = function()
				if vim.bo.filetype == "" then
					return
				end

				lint.try_lint(nil, {
					ignore_errors = true,
				})
			end,
		})
	end,
}
