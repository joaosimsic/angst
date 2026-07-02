---@type Plugin
return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	cmd = { "ConformInfo" },
	opts = function()
		local AdapterScanner = require("backend.shared.AdapterScanner")
		local formatter_opts = { check_executable = true }
		return {
			formatters_by_ft = AdapterScanner:by_filetype("formatter", formatter_opts),
			notify_on_error = true,
		}
	end,
	config = function(_, opts)
		require("conform").setup(opts)

		local Keybinder = require("common.Keybinder")
		local binder = Keybinder.new(nil, "Formatter")

		binder:map({ "n", "v" }, "<leader>f", function()
			local AdapterScanner = require("backend.shared.AdapterScanner")
			local formatter_opts = { check_executable = true }
			if not AdapterScanner:supports_filetype("formatter", vim.bo.filetype, formatter_opts) then
				return
			end

			require("conform").format({
				async = true,
				lsp_format = "fallback",
			})
		end, { desc = "Format buffer" })
	end,
}
