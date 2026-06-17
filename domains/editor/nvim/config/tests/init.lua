vim.opt.rtp:append(".")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	lockfile = vim.fn.stdpath("data") .. "/lazy-lock.json",
	defaults = { lazy = false },
	spec = {
		require("backend"),
		require("frontend"),
	},
})

local runner = require("plenary.test_runner")
runner.run_directory("adapters/suite.lua")
