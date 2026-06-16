local Spec = require("common.Spec")
local scan_adapters = require("backend.shared.scan_adapters")

local specs = Spec.merge({
	require("backend.engines.completion"),
	require("backend.engines.lsp"),
	require("backend.engines.treesitter"),
})

local adapter_plugins = scan_adapters.scan_plugins()

for _, plugin in ipairs(adapter_plugins) do
	if Spec.is_plugin_spec(plugin) then
		table.insert(specs, plugin)
	end
end

return specs
