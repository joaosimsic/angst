---@class DoktorState
local M = {}

---@type DoktorCacheState
M = {
	items = {},
	target_extensions = {},
	is_scanning = false,
	needs_rescan = false,
	row_map = {},
	current_bufnr = nil,
	current_win_id = nil,
	workspace_ns = -1,
	config = {
		auto_start = true,
		namespace_name = "doktor-workspace",
		debounce_ms = 200,
		adapter_overrides = {},
		window = {
			width_ratio = 0.8,
			height_ratio = 0.6,
			border = "rounded",
		},
	},
}

return M
