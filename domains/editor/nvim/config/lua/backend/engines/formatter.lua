local AdapterScanner = require("backend.shared.AdapterScanner")

return {
	"stevearc/conform.nvim",
	event = "BufWritePre",
	cmd = { "ConformInfo" },
	opts = function()
		return {
			formatters_by_ft = AdapterScanner:by_filetype("formatter", { check_executable = true }),
			notify_on_error = true,
		}
	end,
	config = function(_, opts)
		require("conform").setup(opts)

		local Keybinder = require("common.Keybinder")
		local binder = Keybinder.new(nil, "Formatter")

		binder:map({ "n", "v" }, "<leader>f", function()
			require("conform").format({
				async = true,
				lsp_format = "fallback",
			})
		end, "Format buffer")
	end,
}
