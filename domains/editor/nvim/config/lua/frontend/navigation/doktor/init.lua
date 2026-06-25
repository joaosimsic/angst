---@type Plugin
return {
	"doktor",
	virtual = true,
	event = "VeryLazy",
	config = function()
		---@class DoktorModule
		local M = {}

		function M.toggle()
			local pipeline = require("frontend.navigation.doktor.pipeline")
			local window = require("frontend.navigation.doktor.window")
			local keys = require("frontend.navigation.doktor.keys")

			pipeline.trigger_async_diagnostic_pipeline(function(items)
				if #items == 0 then
					vim.notify("No diagnostics found!", vim.log.levels.INFO, { title = "Doktor" })
					return
				end

				local bufnr, win_id = window.create_floating_navigator(items)
				keys.setup_navigation_keys(bufnr, win_id, items)
			end)
		end

		package.loaded["doktor"] = M
		return M
	end,
}
