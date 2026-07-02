---@type Plugin
return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	cmd = { "ConformInfo" },
	opts = function()
		local AdapterScanner = require("backend.shared.AdapterScanner")
		local formatter_opts = { check_executable = true }
		local formatters_by_ft = AdapterScanner:by_filetype("formatter", formatter_opts)
		local all_formatters = AdapterScanner:by_tool("formatter", formatter_opts)
		local formatters = {}

		for name, info in pairs(all_formatters) do
			local cmd = info.cmd
			if type(cmd) == "function" then
				cmd = cmd()
			end
			if type(cmd) == "table" and #cmd > 0 then
				formatters[name] = {
					command = cmd[1],
					args = #cmd > 1 and vim.list_slice(cmd, 2) or nil,
				}
			end
		end

		return {
			formatters_by_ft = formatters_by_ft,
			formatters = formatters,
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
