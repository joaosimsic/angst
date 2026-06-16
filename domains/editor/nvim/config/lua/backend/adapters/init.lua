local adapters = {}

local adapters_path = vim.fn.stdpath("config") .. "/lua/backend/adapters"
local adapter_files = vim.fn.glob(adapters_path .. "/*.lua", false, true)

for _, file in ipairs(adapter_files) do
	local name = vim.fn.fnamemodify(file, ":t:r")
	if name ~= "init" then
		adapters[name] = require("backend.adapters." .. name)
	end
end

return adapters
