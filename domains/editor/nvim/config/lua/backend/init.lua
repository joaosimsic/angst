local PluginLoader = require("common.PluginLoader")

return PluginLoader.load("backend", {
	adapter_plugins = "backend.adapters",
	exclude = { "adapters", "shared" },
})
