vim.g.mapleader = " "
vim.g.maplocalleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

local env_augroup = vim.api.nvim_create_augroup("AngstEnvFiletype", { clear = true })
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	group = env_augroup,
	pattern = { "*.env", ".env", ".env.*" },
	callback = function(ev)
		vim.bo[ev.buf].filetype = "conf"
	end,
})
vim.api.nvim_create_autocmd("FileType", {
	group = env_augroup,
	pattern = "sh",
	callback = function(ev)
		local name = vim.api.nvim_buf_get_name(ev.buf)
		if name:match("%.env") then
			vim.bo[ev.buf].filetype = "conf"
		end
	end,
})

require("lazy").setup({
	lockfile = vim.fn.stdpath("data") .. "/lazy-lock.json",
	defaults = {
		lazy = true,
	},
	clean = true,
	spec = {
		require("config"),
		require("infra"),
		require("backend"),
		require("frontend"),
	},
})
