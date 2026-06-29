local M = {}

local RELOAD_PREFIXES = {
	"backend",
	"common",
	"config",
	"frontend",
	"infra",
}

local function should_reload(module_name)
	for _, prefix in ipairs(RELOAD_PREFIXES) do
		if module_name == prefix or module_name:sub(1, #prefix + 1) == prefix .. "." then
			return true
		end
	end

	return false
end

local function clear_module_cache()
	local reload_modules = {}

	for module_name in pairs(package.loaded) do
		if should_reload(module_name) then
			table.insert(reload_modules, module_name)
		end
	end

	for _, module_name in ipairs(reload_modules) do
		package.loaded[module_name] = nil
	end

	if type(vim.loader) == "table" and type(vim.loader.reset) == "function" then
		vim.loader.reset()
	end
end

function M.nvim_config()
	local config_path = vim.env.MYVIMRC
	if not config_path or config_path == "" then
		config_path = vim.fn.stdpath("config") .. "/init.lua"
	end

	clear_module_cache()

	local ok, err = pcall(function()
		vim.cmd("source " .. vim.fn.fnameescape(config_path))
	end)
	if ok then
		vim.notify("Reloaded Neovim config", vim.log.levels.INFO)
	else
		vim.notify("Failed to reload Neovim config: " .. tostring(err), vim.log.levels.ERROR)
	end
end

return M
