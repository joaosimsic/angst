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
		binder:set_debug(true)

		local function ensure_linewise_register()
			local lines = vim.fn.getreg('"', 1)
			if #lines == 0 then
				return false
			end
			vim.fn.setreg('"', lines, "l")
			return true
		end

		local function paste_inside_block(forward)
			if not ensure_linewise_register() then
				return
			end
			vim.cmd("normal! " .. (forward and "p" or "P"))
			local start = vim.fn.line("'[")
			local finish = vim.fn.line("']")
			if start > 0 and finish > 0 then
				vim.cmd(string.format("%d,%dnormal! ==", start, finish))
			end
		end

		binder:nmap("p", function()
			paste_inside_block(true)
		end, { desc = "Paste after with block-aware indent" })

		binder:nmap("P", function()
			paste_inside_block(false)
		end, { desc = "Paste before with block-aware indent" })


	end,
}
