---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"clipboard-auto-indent",
	virtual = true,
	lazy = false,
	config = function()
		vim.opt.clipboard = "unnamedplus"

		local binder = Keybinder.new(nil, "CLIPBOARD")

		local function paste_inside_block(forward)
			local lines = vim.fn.getreg('"', 1)
			if #lines == 0 then
				return
			end

			vim.cmd("normal! " .. (forward and "]p" or "]P"))
		end

		binder:nmap("p", function()
			paste_inside_block(true)
		end, { desc = "Paste after with block-aware indent" })

		binder:nmap("P", function()
			paste_inside_block(false)
		end, { desc = "Paste before with block-aware indent" })
	end,
}
