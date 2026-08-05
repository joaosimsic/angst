local M = {}

local RELOAD_PREFIXES = {
	"backend",
	"common",
	"config",
	"frontend",
	"infra",
}

function M.reload()
	local luac_dir = vim.fn.stdpath("cache") .. "/luac"
	vim.fn.delete(luac_dir, "rf")
	vim.fn.mkdir(luac_dir, "p")

	if type(vim.loader) == "table" and type(vim.loader.reset) == "function" then
		vim.loader.reset()
	end

	local reload_modules = {}
	for module_name in pairs(package.loaded) do
		for _, prefix in ipairs(RELOAD_PREFIXES) do
			if module_name == prefix or module_name:sub(1, #prefix + 1) == prefix .. "." then
				table.insert(reload_modules, module_name)
				break
			end
		end
	end
	for _, module_name in ipairs(reload_modules) do
		package.loaded[module_name] = nil
	end

	local config_path = vim.env.MYVIMRC
	if not config_path or config_path == "" then
		config_path = vim.fn.stdpath("config") .. "/init.lua"
	end

	local ok, err = pcall(function()
		vim.cmd("source " .. vim.fn.fnameescape(config_path))
	end)
	if ok then
		vim.notify("Reloaded Neovim config", vim.log.levels.INFO)
	else
		vim.notify("Failed to reload Neovim config: " .. tostring(err), vim.log.levels.ERROR)
	end
end

M.nvim_config = M.reload

return M
