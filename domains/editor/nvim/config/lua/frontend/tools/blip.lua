---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	-- dir = "/home/joao/proj/blip",
	"joaosimsic/blip",
	dependencies = { "nvim-lua/plenary.nvim" },
	event = "VeryLazy",
	opts = {
		provider = {
			base_url = "https://opencode.ai/zen/go/v1",
			model = "deepseek-v4-flash",
			api_key_env = "OPENAI_API_KEY",
		},
	},
	config = function(_, opts)
		local blip = require("blip")
		blip.setup(opts)
		local binder = Keybinder.new(nil, "BLIP")
		binder:map({ "n", "v" }, "<leader>m", blip.ask, { desc = "Ask about code" })
		binder:nmap("<leader>q", blip.dismiss, { desc = "Dismiss blip response" })
		binder:nmap("<leader>y", blip.comment, { desc = "Insert explanations as comments" })
	end,
}
