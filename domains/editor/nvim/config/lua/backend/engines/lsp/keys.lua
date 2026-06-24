local Keybinder = require("common.Keybinder")
local LspHydra = require("backend.engines.lsp.hydra")

local M = {}
local instances = {}

---@param bufnr number
function M.setup(bufnr)
	local binder = Keybinder.new(bufnr, "LSP")

	---@type Hydra
	local diag_hydra = LspHydra.create_diagnostics(bufnr)

	instances[bufnr] = {
		binder = binder,
		hydra = diag_hydra,
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

	if inst.hydra then
		inst.hydra:deactivate()
	end

	instances[bufnr] = nil
end

return M
