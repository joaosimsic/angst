---@type Plugin
return {
	"doktor",
	virtual = true,
	event = "VeryLazy",
	config = function()
		---@class DoktorModule
		local M = {}

		function M.toggle()
			local config = require("frontend.navigation.doktor.config")
			local keys = require("frontend.navigation.doktor.keys")

			config.trigger_async_diagnostic_pipeline(function(items)
				local bufnr, win_id = config.create_floating_navigator(items)
				keys.setup_navigation_keys(bufnr, win_id, items)
			end)
		end

		package.loaded["doktor"] = M

		return M
	end,
}
