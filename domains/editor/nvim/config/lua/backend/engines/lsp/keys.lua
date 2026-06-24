local Keybinder = require("common.Keybinder")

local M = {}

local instances = {}

---@param bufnr number
function M.setup(bufnr)
	local binder = Keybinder.new(bufnr, "LSP")
	instances[bufnr] = binder

	binder:nmap("gd", vim.lsp.buf.definition, "Go to definition")
	binder:nmap("K", vim.lsp.buf.hover, "Hover documentation")
	binder:map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")

	binder:nmap("<leader>dn", function()
		vim.diagnostic.jump({ count = 1, wrap = false })
	end, "Go to next diagnostic")

	binder:nmap("<leader>dp", function()
		vim.diagnostic.jump({ count = -1, wrap = false })
	end, "Go to previous diagnostic")
end

function M.purge(bufnr)
	local binder = instances[bufnr]

	if binder then
		binder:purge()
		instances[bufnr] = nil
	end
end

return M
