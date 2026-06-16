---@class EngineOpts
---@field check_executable? boolean 

---@param engine_name string
---@param opts? EngineOpts
---@return table<string, table>
return function(engine_name, opts)
	local active_tools = {}
	opts = opts or {}
	local check_executable = opts.check_executable ~= false

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

		if check_executable and vim.fn.executable(tool_name) ~= 1 then
			goto continue
		end

		active_tools[tool_name] = {
			settings = adapter.lsp_settings and adapter.lsp_settings[tool_name] or nil,
			filetypes = adapter.filetypes,
		}

		::continue::
	end

	return active_tools
end
