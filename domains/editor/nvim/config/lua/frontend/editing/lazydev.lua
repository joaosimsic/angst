local ConfigPath = require("common.ConfigPath")

local function is_under(path, root)
	if type(root) ~= "string" or root == "" or root:sub(1, 1) ~= "/" then
		return false
	end

	local uv = vim.uv or vim.loop
	local normalized = uv.fs_realpath(vim.fs.normalize(path)) or vim.fs.normalize(path)
	local normalized_root = uv.fs_realpath(vim.fs.normalize(root)) or vim.fs.normalize(root)

	return normalized == normalized_root or normalized:sub(1, #normalized_root + 1) == normalized_root .. "/"
end

local function should_skip(workspace, path)
	return ConfigPath.is_config_path(path) or is_under(path, workspace.root)
end

local function guard_workspace_add()
	local Workspace = require("lazydev.workspace")

	if Workspace.__angst_config_guard then
		return
	end

	local original_add = Workspace.add

	function Workspace:add(path)
		if type(path) == "table" then
			local filtered = {}

			for _, item in ipairs(path) do
				if type(item) == "string" and not should_skip(self, item) then
					filtered[#filtered + 1] = item
				end
			end

			if #filtered == 0 then
				return
			end

			return original_add(self, filtered)
		end

		if should_skip(self, path) then
			return
		end

		return original_add(self, path)
	end

	Workspace.__angst_config_guard = true
end

return {
	"folke/lazydev.nvim",
	ft = "lua",
	opts = {
		library = {
			{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
		},
	},
	config = function(_, opts)
		require("lazydev").setup(opts)
		guard_workspace_add()
	end,
}
