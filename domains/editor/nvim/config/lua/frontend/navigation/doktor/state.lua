---@class DoktorState
local M = {}

---@type DoktorCacheState
M = {
	items = {},
	target_extensions = {},
	is_scanning = false,
	row_map = {},
	current_bufnr = nil,
	current_win_id = nil,
}

return M
