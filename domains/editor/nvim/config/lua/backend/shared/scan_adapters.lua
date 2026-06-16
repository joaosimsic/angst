---@alias LspCmd string[]|fun():string[]|nil

---@class AdapterLspInfo
---@field cmd LspCmd
---@field settings table|nil
---@field filetypes string[]|nil

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

		if check_executable then
			local cmd_field = engine_name .. "_cmd"
			local cmd = adapter[cmd_field]
			local executable_name

			if type(cmd) == "table" then
				executable_name = cmd[1]
			elseif type(cmd) == "function" then
				executable_name = nil
			else
				executable_name = tool_name
			end

			if executable_name and vim.fn.executable(executable_name) ~= 1 then
				goto continue
			end
		end

		active_tools[tool_name] = {
			cmd = adapter.lsp_cmd,
			settings = adapter.lsp_settings and adapter.lsp_settings[tool_name] or nil,
			filetypes = adapter.filetypes,
		}

		::continue::
	end

	return active_tools
end
