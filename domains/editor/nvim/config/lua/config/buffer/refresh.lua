---@type Plugin
return {
	"buffer-refresh",
	virtual = true,
	lazy = false,
	config = function()
		vim.o.autoread = true

		local group = vim.api.nvim_create_augroup("BufferRefresh", { clear = true })

		vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
			group = group,
			callback = function()
				if vim.bo.buftype == "terminal" then
					return
				end

				if vim.fn.mode() ~= "c" then
					vim.cmd("checktime")
				end
			end,
			pattern = { "*" },
		})
	end,
}
