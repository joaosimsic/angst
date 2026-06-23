local M = {}

---@alias AdapterCmd string[]|fun():string[]|nil

---@class AdapterToolInfo
---@field cmd AdapterCmd
---@field settings table|nil
---@field filetypes string[]|nil

---@param cmd AdapterCmd
---@return string[]|nil
function M.resolve_cmd(cmd)
	if type(cmd) == "function" then
		return cmd()
	end

	return cmd
end

---@param adapter Adapter
---@param engine_name string
---@return string[]|nil
function M.names(adapter, engine_name)
	local value = adapter[engine_name]

	if type(value) == "string" then
		return { value }
	end

	if type(value) == "table" then
		return value
	end
end

---@param adapter Adapter
---@param engine_name string
---@return AdapterCmd
function M.cmd(adapter, engine_name)
	return adapter[engine_name .. "_cmd"]
end

---@param adapter Adapter
---@param engine_name string
---@param tool_name string
---@return string|nil
function M.executable(adapter, engine_name, tool_name)
	local raw_cmd = M.cmd(adapter, engine_name)
	local resolved_cmd = M.resolve_cmd(raw_cmd)

	if type(resolved_cmd) == "table" then
		return resolved_cmd[1]
	end

	if type(raw_cmd) == "function" then
		return nil
	end

	return tool_name
end

---@param adapter Adapter
---@param engine_name string
---@param tool_name string
---@return AdapterToolInfo
function M.info(adapter, engine_name, tool_name)
	local settings = adapter.lsp_settings
	if type(adapter[engine_name]) == "table" and settings then
		settings = settings[tool_name]
	end

	return {
		cmd = M.cmd(adapter, engine_name),
		settings = settings,
		filetypes = adapter.filetypes,
	}
end

return M
