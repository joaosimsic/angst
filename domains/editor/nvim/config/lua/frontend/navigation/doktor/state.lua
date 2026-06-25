---@class DoktorState
local M = {}

---@type DoktorCacheState
M = {
	items = {},
	target_extensions = {},
	is_scanning = false,
	row_map = {},
}

return M
