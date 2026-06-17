local function get_config_root()
	local source = debug.getinfo(1, "S").source
	local path = source:sub(1, 1) == "@" and source:sub(2) or "."
	return vim.fn.fnamemodify(path, ":p:h:h")
end

local function find_plenary()
	local data_dir = vim.fn.stdpath("data")
	local candidate = data_dir .. "/lazy/plenary.nvim"

	if (vim.uv or vim.loop).fs_stat(candidate) then
		return candidate
	end

	local share_dir = vim.fn.fnamemodify(data_dir, ":h")
	local matches = vim.fn.glob(share_dir .. "/*/lazy/plenary.nvim", false, true)

	if #matches > 0 then
		return matches[1]
	end

	error("plenary.nvim not found in any live plugin directory. Run lazy sync first.")
end

local config_root = get_config_root()
vim.opt.rtp:append(config_root)

local plenary_dir = find_plenary()
vim.opt.rtp:append(plenary_dir)
vim.cmd("runtime plugin/plenary.vim")

vim.cmd("cd " .. vim.fn.fnameescape(config_root))

require("plenary.test_harness").test_file(config_root .. "/tests/adapters/suite.lua")
