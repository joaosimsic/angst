local M = {}

---@return table<string, DoktorGroupedFile>
function M.get_structured_diagnostics()
	---@type Diagnostics
	local all_diagnostics = vim.diagnostic.get(nil)
	---@type table<string, DoktorGroupedFile>
	local grouped = {}
	local buf_path_cache = {}

	for _, diag in ipairs(all_diagnostics) do
		local bufnr = diag.bufnr
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			local relative_path = buf_path_cache[bufnr]
			if not relative_path then
				local full_path = vim.api.nvim_buf_get_name(bufnr)
				relative_path = vim.fn.fnamemodify(full_path, ":.")
				buf_path_cache[bufnr] = relative_path
			end

			if not grouped[relative_path] then
				grouped[relative_path] = {
					path = relative_path,
					diagnostics = {},
					lines = {},
					sorted_lines = {},
				}
			end

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
	end

	local data_list = {}
	for _, data in pairs(grouped) do
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

	return data_list
end

return M
