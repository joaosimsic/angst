---@type Plugin
return {
	"clipboard",
	virtual = true,
	lazy = false,
	config = function()
		local is_remote = vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil
		local has_display = vim.env.DISPLAY ~= nil or vim.env.WAYLAND_DISPLAY ~= nil

		if not is_remote and has_display then
			return
		end

		local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
		if not ok then
			return
		end

		vim.g.clipboard = {
			name = "OSC 52",
			copy = {
				["+"] = osc52.copy("+"),
				["*"] = osc52.copy("*"),
			},
			paste = {
				["+"] = osc52.paste("+"),
				["*"] = osc52.paste("*"),
			},
		}

    vim.opt.clipboard = "unnamedplus"
	end,
}
