---@class DoktorState
local M = {}

---@type DoktorCacheState
M.state = {
	items = {},
	target_extensions = {},
	is_scanning = false,
	row_map = {},
}

return M
