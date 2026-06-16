local adapters = {}
local adapters_path = vim.fn.stdpath("config") .. "/lua/backend/adapters"

local adapter_files = vim.fn.glob(adapters_path .. "/*.lua", false, true)
for _, file in ipairs(adapter_files) do
	local name = vim.fn.fnamemodify(file, ":t:r")
	if name ~= "init" then
		adapters[name] = require("backend.adapters." .. name)
	end
end

local adapter_dirs = vim.fn.glob(adapters_path .. "/*/init.lua", false, true)
for _, file in ipairs(adapter_dirs) do
	local dir_path = vim.fn.fnamemodify(file, ":h")
	local name = vim.fn.fnamemodify(dir_path, ":t")

	if not adapters[name] then
		adapters[name] = require("backend.adapters." .. name)
	end
end

return adapters
