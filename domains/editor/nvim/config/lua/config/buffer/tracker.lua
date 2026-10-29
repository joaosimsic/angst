---@type Plugin
return {
	"buffer-tracker",
	virtual = true,
	lazy = false,
	config = function()
		local group = vim.api.nvim_create_augroup("BufferTracker", { clear = true })

		vim.api.nvim_create_autocmd("BufReadPost", {
			group = group,
			callback = function()
				local mark = vim.api.nvim_buf_get_mark(0, '"')
				local count = vim.api.nvim_buf_line_count(0)

				if mark[1] > 0 and mark[1] <= count then
					pcall(vim.api.nvim_win_set_cursor, 0, mark)
				end
			end,
		})
	end,
}
