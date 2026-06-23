local M = {}

---@class LspUtils

---@param markers string[]
---@return function
function M.make_root_dir_finder(markers)
	return function(bufnr, on_dir)
		local path = vim.api.nvim_buf_get_name(bufnr)

		if path == "" then
			return
		end

		local root = vim.fs.root(path, markers) or vim.fs.dirname(path)

		on_dir(root)
	end
end

return M
