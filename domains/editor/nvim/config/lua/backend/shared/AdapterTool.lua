local M = {}

---@alias AdapterCmd string[]|fun():string[]|nil

---@class AdapterToolInfo
---@field cmd AdapterCmd
---@field settings table|nil
---@field init_options table|nil
---@field root_markers string[]|nil
---@field root_dir function|nil
---@field handlers function|nil
---@field filetypes string[]|nil
---@field compiler string|nil

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
---@param field_name string
---@return table|nil
local function server_field(adapter, engine_name, tool_name, field_name)
	local value = adapter[field_name]
	if type(adapter[engine_name]) == "table" and value then
		value = value[tool_name]
	end

	return value
end

---@param adapter Adapter
---@param engine_name string
---@param tool_name string
---@return AdapterToolInfo
function M.info(adapter, engine_name, tool_name)
	---@type AdapterToolInfo
	local info = {
		cmd = M.cmd(adapter, engine_name),
		settings = server_field(adapter, engine_name, tool_name, "lsp_settings"),
		init_options = server_field(adapter, engine_name, tool_name, "lsp_init_options"),
		root_markers = server_field(adapter, engine_name, tool_name, "lsp_root_markers"),
		root_dir = server_field(adapter, engine_name, tool_name, "lsp_root_dir"),
		handlers = server_field(adapter, engine_name, tool_name, "lsp_handlers"),
		filetypes = adapter.filetypes,
	}

	if engine_name == "doktor" then
		info.compiler = adapter.doktor_compiler
	end

	return info
end

return M
