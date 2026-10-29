---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"git-menu",
	virtual = true,
	event = "VeryLazy",
	dependencies = { "ibhagwan/fzf-lua" },
	config = function()
		local binder = Keybinder.new(nil, "GIT-MENU")

		binder:nmap("<leader>gl", function()
			local all_actions = require("frontend.tools.git_menu_actions")

			local attached = pcall(require, "gitsigns")
				and vim.b.gitsigns_status_dict ~= nil

			local labels = {}
			local by_label = {}

			for _, action in ipairs(all_actions) do
				if not action.needs_git or attached then
					labels[#labels + 1] = action.label
					by_label[action.label] = action
				end
			end

			require("fzf-lua").fzf_exec(labels, {
				prompt = "Git> ",
				winopts = { height = 0.40, width = 0.50 },
				actions = {
					["default"] = function(selected)
						local action = by_label[selected[1]]
						if action then
							action.run()
						end
					end,
				},
			})
		end, { desc = "Git action menu" })
	end,
}
