---@type Plugin
return {
	"theme",
	virtual = true,
	lazy = false,
	priority = 1000,
	config = function()
		vim.g.colors_name = "angst"

		local colors = require("config.theme.colors").get()

		require("config.theme.groups").apply(colors)
	end,
}
