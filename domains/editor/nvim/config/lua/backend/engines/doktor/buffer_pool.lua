local config_mod = require("backend.engines.doktor.config")

local M = {}

---@type integer[]
local order = {}

---@param bufnr integer
local function remove_from_order(bufnr)
	for index = #order, 1, -1 do
		if order[index] == bufnr then
			table.remove(order, index)
		end
	end
end

---@param bufnr integer
function M.evict(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		remove_from_order(bufnr)
		return
	end

	vim.diagnostic.reset(vim.api.nvim_create_namespace("doktor.lsp"), bufnr)
	vim.diagnostic.reset(vim.api.nvim_create_namespace("doktor.lint"), bufnr)
	pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
	remove_from_order(bufnr)
end

---@param bufnr integer
function M.retain(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	vim.bo[bufnr].bufhidden = "hide"
	remove_from_order(bufnr)
	order[#order + 1] = bufnr

	local max = config_mod.get().max_hidden_buffers
	while #order > max do
		M.evict(order[1])
	end
end

---@param bufnr integer
---@param created boolean
function M.discard(bufnr, created)
	if not created or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
	remove_from_order(bufnr)
end

return M
