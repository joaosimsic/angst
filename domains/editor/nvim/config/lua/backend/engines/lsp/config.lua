local AdapterScanner = require("backend.shared.AdapterScanner")

local enabled_servers = {}

local function make_server_config(server_opts, capabilities, existing_config)
	local cmd = server_opts.cmd
	if type(cmd) == "function" then
		cmd = cmd()
	end

	if not cmd then
		return nil
	end

	local config = {
		cmd = cmd,
		capabilities = capabilities,
		filetypes = server_opts.filetypes or existing_config.filetypes,
	}

	local final_config = vim.tbl_deep_extend("force", existing_config, config, server_opts)
	final_config.cmd = cmd

	return final_config
end

local function enable_for_filetype(server_name, all_servers, capabilities, ft, logger)
	if enabled_servers[server_name] then
		return
	end

	local server_opts = all_servers[server_name]
	local filetypes = server_opts.filetypes
	if not filetypes or not vim.tbl_contains(filetypes, ft) then
		return
	end

	local existing_config = vim.lsp.config[server_name] or {}
	local config = make_server_config(server_opts, capabilities, existing_config)
	if not config then
		return
	end

	vim.lsp.config(server_name, config)
	vim.lsp.enable(server_name)
	enabled_servers[server_name] = true

	if logger then
		logger:debug(function()
			return string.format("Enabled LSP '%s' for filetype '%s'", server_name, ft)
		end)
	end
end

local M = {}

---@param logger Logger|nil
M.setup = function(logger)
	local capabilities = vim.deepcopy(require("backend.engines.completion.config").capabilities())
	capabilities.experimental = capabilities.experimental or {}
	capabilities.experimental.serverStatusNotification = true

	local function is_env_file(bufnr)
		local name = vim.api.nvim_buf_get_name(bufnr)
		return name:match("%.env") ~= nil
	end

	local all_servers = AdapterScanner:by_tool("lsp")
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype

	if not is_env_file(bufnr) then
		for server_name, _ in pairs(all_servers) do
			enable_for_filetype(server_name, all_servers, capabilities, ft, logger)
		end
	end

	local group = vim.api.nvim_create_augroup("LspDynamicEnable", { clear = true })

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		callback = function(event)
			if is_env_file(event.buf) then
				return
			end

			local new_ft = vim.bo[event.buf].filetype
			if not new_ft or new_ft == "" then
				return
			end

			for server_name, _ in pairs(all_servers) do
				enable_for_filetype(server_name, all_servers, capabilities, new_ft, logger)
			end
		end,
	})
end

return M
