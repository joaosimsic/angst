return {
	"stevearc/conform.nvim",
	event = "BufWritePre",
	cmd = { "ConformInfo" },
	opts = function()
		local scan_adapters = require("backend.shared.scan_adapters")
		local formatters_by_ft = {}

		for formatter_name, opts in pairs(scan_adapters("formatter", { check_executable = true })) do
			for _, ft in ipairs(opts.filetypes or {}) do
				formatters_by_ft[ft] = formatters_by_ft[ft] or {}
				table.insert(formatters_by_ft[ft], formatter_name)
			end
		end

		for _, formatters in pairs(formatters_by_ft) do
			table.sort(formatters)
		end

		return {
			formatters_by_ft = formatters_by_ft,
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
