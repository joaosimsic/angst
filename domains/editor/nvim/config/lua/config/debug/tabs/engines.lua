local AdapterScanner = require("backend.shared.AdapterScanner")

local M = {}

---@param bufnr integer
---@return string[]
function M.render(bufnr)
	local ft = vim.bo[bufnr].filetype
	if ft == "" then
		ft = "unsupported"
	end

	local lines = {
		string.format(" Buffer: %d | Filetype: %s", bufnr, ft),
		"------------------------------",
		"",
	}

	table.insert(lines, "LSP:")
	local lsp_clients = vim.lsp.get_clients({ bufnr = bufnr })

	if #lsp_clients == 0 then
		table.insert(lines, "  No active clients attached.")
	end

	for _, client in ipairs(lsp_clients) do
		table.insert(lines, string.format("  Active [%s] (ID: %d)", client.name, client.id))
	end

	table.insert(lines, "")

	table.insert(lines, "Tree-sitter:")
	local has_highlighter = vim.treesitter.highlighter.active[bufnr] ~= nil

	if not has_highlighter then
		table.insert(lines, "  Inactive / No parser attached.")
	end

	local lang = vim.treesitter.language.get_lang(ft) or ft
	table.insert(lines, string.format("  Active (Parser: %s)", lang))

	table.insert(lines, "")

	table.insert(lines, "Formatter:")
	local formatters = AdapterScanner:tools_for_filetype("formatter", ft, { check_executable = true })

	if #formatters == 0 then
		table.insert(lines, "  No formatter configured.")
	end
	table.insert(lines, "  Configured: " .. table.concat(formatters, ", "))

	table.insert(lines, "")

	table.insert(lines, "Linter:")
	local linters = AdapterScanner:tools_for_filetype("linter", ft, { check_executable = true })

	if #linters == 0 then
		table.insert(lines, "  State: None configured.")
	else
		table.insert(lines, "  Configured: " .. table.concat(linters, ", "))
	end

	return lines
end

return M
