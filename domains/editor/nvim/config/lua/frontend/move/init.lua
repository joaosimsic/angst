---@type Plugin
return {
	"move",
	virtual = true,
	event = "VeryLazy",
	config = function()
    require("frontend.move.keys").setup()
	end,
}
