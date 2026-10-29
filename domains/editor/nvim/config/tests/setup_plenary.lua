local M = {}

function M.config_root()
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

	return nil
end

function M.ensure_plenary()
	local plenary_dir = find_plenary()
	if plenary_dir then
		return plenary_dir
	end

	local data_dir = vim.fn.stdpath("data")
	local target = data_dir .. "/lazy/plenary.nvim"
	local repo = "https://github.com/nvim-lua/plenary.nvim.git"

	vim.fn.mkdir(data_dir .. "/lazy", "p")
	local out = vim.fn.system({ "git", "clone", "--depth=1", repo, target })

	if vim.v.shell_error ~= 0 then
		error("Failed to install plenary.nvim:\n" .. out)
	end

	plenary_dir = find_plenary()
	if not plenary_dir then
		error("plenary.nvim installation succeeded but could not be found")
	end
	return plenary_dir
end

function M.prepare()
	local config_root = M.config_root()
	-- Drop a rendered copy at ~/.config/nvim so the working tree under test
	-- is the only config source, then pin it first on the runtime path.
	vim.opt.rtp:remove(vim.fn.expand("~/.config/nvim"))
	vim.opt.rtp:prepend(config_root)

	local plenary_dir = M.ensure_plenary()
	vim.opt.rtp:append(plenary_dir)
	vim.cmd("runtime plugin/plenary.vim")

	vim.cmd("cd " .. vim.fn.fnameescape(config_root))

	return config_root
end

return M
