local M = {}

function M.setup(logger)
	vim.api.nvim_create_user_command("Anchor", function(opts)
		local args = vim.split(opts.args or "", "%s+")
		local subcmd = args[1] or ""

		if subcmd == "clear" then
			vim.g.anchor_path = nil
			logger:debug("Anchor cleared")
			local win = vim.fn.bufwinid(vim.fn.bufnr())
			if win and win ~= -1 and vim.bo.filetype == "yazi" then
				pcall(vim.api.nvim_win_set_config, win, { title = "yazi" })
			end
			vim.cmd("redrawstatus!")
		elseif subcmd == "show" then
			if vim.g.anchor_path then
				logger:debug('Anchored to "' .. vim.g.anchor_path.path .. '"')
			else
				logger:debug("No anchor set")
			end
		end
	end, {
		nargs = "?",
		complete = function()
			return { "clear", "show" }
		end,
		desc = "Manage anchor: no args to toggle, clear to remove, show to display path",
	})
end

return M
