local M = {}

function M.setup()
	vim.api.nvim_create_autocmd("User", {
		pattern = "OpencodeEvent:session.idle",
		callback = function()
			vim.notify("OpenCode finished responding", vim.log.levels.INFO)
		end,
		desc = "Notify when OpenCode finishes responding",
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "OpencodeEvent:edit.start",
		callback = function()
			vim.cmd("silent! wall")
		end,
		desc = "Auto-save buffers before OpenCode edits",
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "OpencodeEvent:error",
		callback = function(args)
			local event = args.data.event
			vim.notify("OpenCode error: " .. (event.message or "Unknown"), vim.log.levels.ERROR)
		end,
		desc = "Notify on OpenCode errors",
	})
end

return M
