---@type DoktorCacheState
local State = require("frontend.navigation.doktor.state")
---@type Logger
local logger = require("frontend.navigation.doktor.logger")

local M = {}

---@class DoktorDedupKey
---@field filename string
---@field lnum integer
---@field col integer
---@field severity integer
---@field message string

---@param filename string
---@param lnum integer
---@param col integer
---@param severity integer
---@param message string
---@return string
local function dedup_key(filename, lnum, col, severity, message)
	return string.format("%s:%d:%d:%d:%s", filename, lnum, col, severity, message)
end

---@return table<string, DoktorGroupedFile>
function M.get_structured_diagnostics()
	---@type vim.Diagnostic[]
	local all_diagnostics = vim.diagnostic.get(nil)

	---@type table<string, DoktorGroupedFile>
	local grouped = {}

	---@type table<string, boolean>
	local seen = {}

	---@type table<integer, string>
	local buf_path_cache = {}

	for _, diag in ipairs(all_diagnostics) do
		---@type integer?
		local bufnr = diag.bufnr
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			---@type string
			local relative_path = buf_path_cache[bufnr]
			if not relative_path then
				---@type string
				local full_path = vim.api.nvim_buf_get_name(bufnr)
				relative_path = vim.fn.fnamemodify(full_path, ":.")
				buf_path_cache[bufnr] = relative_path
			end

			---@type string
			local key = dedup_key(
				relative_path,
				diag.lnum,
				diag.col,
				diag.severity,
				diag.message or ""
			)

			if seen[key] then
				goto continue
			end
			seen[key] = true

			if not grouped[relative_path] then
				grouped[relative_path] = {
					path = relative_path,
					diagnostics = {},
					lines = {},
					sorted_lines = {},
				}
			end

			---@type integer
			local lnum = diag.lnum
			if not grouped[relative_path].lines[lnum] then
				grouped[relative_path].lines[lnum] = {
					lnum = lnum,
					col = diag.col,
					diags = {},
				}
			end

			table.insert(grouped[relative_path].lines[lnum].diags, diag)
			table.insert(grouped[relative_path].diagnostics, diag)
		end
		::continue::
	end

	---@type DoktorGroupedFile[]
	local data_list = {}
	for _, data in pairs(grouped) do
		---@type DoktorLineData[]
		local sorted_lines = {}
		for _, line_data in pairs(data.lines) do
			table.insert(sorted_lines, line_data)
		end
		table.sort(sorted_lines, function(a, b)
			return a.lnum < b.lnum
		end)
		data.sorted_lines = sorted_lines
		table.insert(data_list, data)
	end

	logger:debug(function()
		---@type integer
		local total_diags = 0
		for _, data in ipairs(data_list) do
			total_diags = total_diags + #data.diagnostics
		end
		return string.format("Collected %d diagnostics across %d files", total_diags, #data_list)
	end)

	return data_list
end

return M
