---@type Plugin
return {
	"theme",
	virtual = true,
	lazy = false,
	priority = 1000,
	config = function()
		vim.g.colors_name = "angst"

		local palette = require("config.theme.palette").get()

		require("config.theme.groups").apply(palette)
	end,
}
