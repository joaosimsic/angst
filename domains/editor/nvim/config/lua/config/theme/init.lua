---@type Plugin
return {
	"theme",
	virtual = true,
	lazy = false,
	priority = 1000,
	config = function()
		vim.g.colors_name = "angst"

		require("config.theme.groups").apply()
	end,
}
