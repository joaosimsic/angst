local Keybinder = require("common.Keybinder")

local M = {}
local instances = {}

---@param bufnr number
function M.setup(bufnr)
	local binder = Keybinder.new(bufnr, "LSP")

	instances[bufnr] = {
		binder = binder,
	}

	binder:nmap("gd", vim.lsp.buf.definition, "Go to definition")
	binder:nmap("K", vim.lsp.buf.hover, "Hover documentation")
	binder:map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
end

function M.purge(bufnr)
	local inst = instances[bufnr]
	if not inst then
		return
	end

	inst.binder:purge()

	instances[bufnr] = nil
end

return M
