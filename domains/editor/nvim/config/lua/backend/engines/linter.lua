---@type Plugin
return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },

	config = function()
		local AdapterScanner = require("backend.shared.AdapterScanner")
		local linter_opts = { check_executable = true }
		local lint = require("lint")
		lint.linters_by_ft = AdapterScanner:by_filetype("linter", linter_opts)

		for _, adapter in pairs(AdapterScanner:adapters()) do
			if adapter.linter_def then
				for name, def in pairs(adapter.linter_def) do
					if not lint.linters[name] then
						lint.linters[name] = {
							cmd = def.cmd,
							stdin = def.stdin,
							args = def.args,
							ignore_exitcode = def.ignore_exitcode,
							parser = require("lint.parser").from_pattern(
								def.pattern,
								def.captures,
								def.severity
							),
						}
					end
				end
			end
		end

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
