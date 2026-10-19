vim.g.mapleader = " "
vim.g.maplocalleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

local function clone()
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--depth=1", "--branch=stable", lazyrepo, lazypath })
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

local ok, lazy = pcall(require, "lazy")

if not ok or type(lazy) ~= "table" then
	vim.fn.delete(lazypath, "rf")
	clone()
	package.loaded["lazy"] = nil
	vim.opt.rtp:prepend(lazypath)
	ok, lazy = pcall(require, "lazy")
	if not ok or type(lazy) ~= "table" then
		vim.api.nvim_echo({
			{ "Failed to load lazy.nvim: " .. tostring(lazy), "ErrorMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end

local lock_lua = lazypath .. "/lua/lazy/manage/lock.lua"
local lines = vim.fn.readfile(lock_lua)
for i, line in ipairs(lines) do
	if line:find("info%.branch or assert%(Git%.get_branch") then
		lines[i] = [[        branch = info.branch or Git.get_branch(plugin) or info.commit,]]
	end
end
vim.fn.writefile(lines, lock_lua)

lazy.setup({
	lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
	defaults = {
		lazy = true,
	},
	git = {
		depth = 1,
	},
	clean = true,
	spec = {
		require("config"),
		require("infra"),
		require("backend"),
		require("frontend"),
	},
})
