local scan_adapters = require("backend.shared.scan_adapters")

local function is_plugin_spec(spec)
	return type(spec) == "table" and (type(spec[1]) == "string" or type(spec.dir) == "string")
end

local function collect_specs(source, target)
	if type(source) ~= "table" then
		return
	end

	if is_plugin_spec(source) then
		table.insert(target, source)
		return
	end

	for _, spec in ipairs(source) do
		collect_specs(spec, target)
	end
end

local specs = {}

collect_specs(require("backend.engines.completion"), specs)
collect_specs(require("backend.engines.lsp"), specs)
collect_specs(require("backend.engines.treesitter"), specs)

local adapter_plugins = scan_adapters.scan_plugins()

for _, plugin in ipairs(adapter_plugins) do
	if is_plugin_spec(plugin) then
		table.insert(specs, plugin)
	end
end

return specs
