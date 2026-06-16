-- @param engine_name string
-- @param default_cmds table|nil
-- @return table
return function(engine_name, default_cmds)
	local active_tools = {}
	default_cmds = default_cmds or {}

	local ok_idx, adapters = pcall(require, "backend.adapters")
	if not ok_idx or type(adapters) ~= "table" then
		return active_tools
	end

	for _, adapter in pairs(adapters) do
		if type(adapter) ~= "table" then
			goto continue
		end

		local tool_name = adapter[engine_name]
		if type(tool_name) ~= "string" then
			goto continue
		end

		local cmd_opt = default_cmds[tool_name]
		local binary = type(cmd_opt) == "table" and cmd_opt[1] or tool_name

		if vim.fn.executable(binary) == 1 then
			active_tools[tool_name] = {
				settings = adapter.lsp_settings and adapter.lsp_settings[tool_name] or nil,
				filetypes = adapter.filetypes,
			}
		end

		::continue::
	end

	return active_tools
end
