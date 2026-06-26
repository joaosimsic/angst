---@type Plugin
return {
	"doktor",
	virtual = true,
	event = "VeryLazy",
	config = function()
		---@class DoktorModule
		local M = {}

		local window = require("frontend.navigation.doktor.window")
		local keys = require("frontend.navigation.doktor.keys")
		local config_mod = require("frontend.navigation.doktor.config")
		---@type DoktorCacheState
		local State = require("frontend.navigation.doktor.state")
		---@type Logger
		local logger = require("frontend.navigation.doktor.logger")
		local engine = require("frontend.navigation.doktor.engine")

		---@type DoktorConfig
		local config = config_mod.get()

		---@type integer
		local workspace_ns = vim.api.nvim_create_namespace(config.namespace_name)
		State.workspace_ns = workspace_ns

		logger:info(function()
			return string.format("Workspace namespace created: '%s' (id=%d)", config.namespace_name, workspace_ns)
		end)

		engine.setup(workspace_ns, config)

		vim.api.nvim_create_autocmd("DiagnosticChanged", {
			group = vim.api.nvim_create_augroup("DoktorWindowUpdater", { clear = true }),
			callback = function()
				if State.current_bufnr and vim.api.nvim_buf_is_valid(State.current_bufnr) then
					vim.schedule(function()
						window.update_buffer_contents(State.current_bufnr)
					end)
				end
			end,
		})

		vim.api.nvim_create_autocmd("LspProgress", {
			group = vim.api.nvim_create_augroup("DoktorLSPStatusTracker", { clear = true }),
			callback = function(ev)
				---@type table
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

		---@return nil
		function M.toggle()
			if State.current_win_id and vim.api.nvim_win_is_valid(State.current_win_id) then
				vim.api.nvim_win_close(State.current_win_id, true)
				logger:info(function()
					return "Doktor window closed"
				end)
				return
			end

			---@type vim.lsp.Client[]
			local clients = vim.lsp.get_clients()
			if not clients or #clients == 0 then
				logger:warn(function()
					return "No LSPs attached"
				end)
				return
			end

			---@type integer
			local bufnr
			---@type integer
			local win_id
			bufnr, win_id = window.render_diagnostics_window()
			keys.setup_navigation_keys(bufnr, win_id)
			logger:info(function()
				return "Doktor window opened"
			end)
		end

		---@return nil
		function M.scan()
			---@type integer
			local bufnr = vim.api.nvim_get_current_buf()
			---@type string
			local filetype = vim.bo[bufnr].filetype
			logger:info(function()
				return string.format("Manual scan requested for filetype '%s'", filetype)
			end)
			engine.trigger_scan(filetype, workspace_ns, config)
		end

		---@param opts? table
		---@return nil
		function M.setup(opts)
			config = config_mod.setup(opts)
			State.config = config
			logger:info(function()
				return "Doktor reconfigured"
			end)
		end

		package.loaded["doktor"] = M
		return M
	end,
}
