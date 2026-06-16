local Keybinder = require("common.Keybinder")

local M = {}

---@param bufnr number
function M.setup(bufnr)
	local binder = Keybinder.new(bufnr, "LSP")

	binder:nmap("gd", vim.lsp.buf.definition, "Go to definition")
	binder:nmap("K", vim.lsp.buf.hover, "Hover documentation")
	binder:map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
end

return M
