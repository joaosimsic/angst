---@class DoktorState
local M = {}

---@type DoktorCacheState
M.state = {
	items = {},
	target_extensions = {},
	is_scanning = false,
}

return M
