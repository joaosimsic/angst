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
		---@type DoktorCacheState
		local State = require("frontend.navigation.doktor.state")
		---@type Logger
		local logger = require("frontend.navigation.doktor.logger")

		vim.api.nvim_create_autocmd("DiagnosticChanged", {
			group = vim.api.nvim_create_augroup("DoktorBackgroundScanner", { clear = true }),
			callback = function()
				pipeline.trigger_async_diagnostic_pipeline(function(_)
					if State.current_bufnr and vim.api.nvim_buf_is_valid(State.current_bufnr) then
						vim.schedule(function()
							window.update_buffer_contents(State.current_bufnr)
						end)
					end
				end)
			end,
		})

		vim.api.nvim_create_autocmd("LspProgress", {
			group = vim.api.nvim_create_augroup("DoktorLSPStatusTracker", { clear = true }),
			callback = function(ev)
				local value = ev.data.params.value

				if value.kind == "begin" then
					State.is_scanning = true
				elseif value.kind == "end" then
					State.is_scanning = false
				end

				if State.current_bufnr and vim.api.nvim_buf_is_valid(State.current_bufnr) then
					vim.schedule(function()
						window.update_buffer_contents(State.current_bufnr)
					end)
				end
			end,
		})

		function M.toggle()
			if State.current_win_id and vim.api.nvim_win_is_valid(State.current_win_id) then
				vim.api.nvim_win_close(State.current_win_id, true)
				return
			end

			local clients = vim.lsp.get_clients()
			if not clients or #clients == 0 then
				logger:warn(function()
					return "No LSPs attached"
				end)
				return
			end

			local bufnr, win_id = window.render_diagnostics_window()
			keys.setup_navigation_keys(bufnr, win_id)
		end

		package.loaded["doktor"] = M
		return M
	end,
}
