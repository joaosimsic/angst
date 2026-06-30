---@type Plugin
return {
	"clipboard-keys",
	virtual = true,
	lazy = false,
	config = function()
		local Keybinder = require("common.Keybinder")
		local binder = Keybinder.new(nil, "CLIPBOARD")

		binder:map({ "n", "v" }, "<leader>y", function()
			vim.cmd('normal! "0y')
		end, { desc = "Yank to internal register only" })

		binder:nmap("<leader>Y", function()
			vim.cmd('normal! "0Y')
		end, { desc = "Yank line to internal register only" })

		binder:nmap("<leader>p", function()
			vim.cmd('normal! "0p')
		end, { desc = "Paste from internal register after cursor" })

		binder:nmap("<leader>P", function()
			vim.cmd('normal! "0P')
		end, { desc = "Paste from internal register before cursor" })

		binder:vmap("<leader>p", function()
			vim.cmd('normal! "_d"0P')
		end, { desc = "Paste over selection using internal register" })

		binder:map({ "n", "v" }, "<leader>d", function()
			vim.cmd('normal! "_d')
		end, { desc = "Delete without touching clipboard" })
	end,
}
