---@type Plugin
return {
	"doktor",
	virtual = true,
	event = "VeryLazy",
	config = function()
		---@class DoktorModule
		local M = {}
		local pipeline = require("frontend.navigation.doktor.pipeline")
		local window = require("frontend.navigation.doktor.window")
		local keys = require("frontend.navigation.doktor.keys")
		local State = require("frontend.navigation.doktor.state")
		local logger = require("frontend.navigation.doktor.logger")

		vim.api.nvim_create_autocmd("DiagnosticChanged", {
			group = vim.api.nvim_create_augroup("DoktorBackgroundScanner", { clear = true }),
			callback = function()
				pipeline.trigger_async_diagnostic_pipeline(function(_)
				end)
			end,
		})

		function M.toggle()
			local clients = vim.lsp.get_clients()
			if not clients or #clients == 0 then
				logger:error(function()
					return "No LSPs attached"
				end)
				vim.notify("No LSPs attached!", vim.log.levels.WARN, { title = "Doktor" })
				return
			end

			local items = State.state.items
			if not items or #items == 0 then
				vim.notify("No diagnostics found!", vim.log.levels.INFO, { title = "Doktor" })
				return
			end

			local bufnr, win_id = window.render_diagnostics_window()
			keys.setup_navigation_keys(bufnr, win_id)
		end

		package.loaded["doktor"] = M
		return M
	end,
}
