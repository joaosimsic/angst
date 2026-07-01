---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Logger
local Logger = require("common.Logger")

---@type Plugin
return {
	"mikavilpas/yazi.nvim",
	version = "*",
	event = "VeryLazy",
	opts = {
		open_for_directories = false,
		keymaps = {
			show_help = "<f1>",
		},
		hooks = {
			on_yazi_ready = function(buffer, config, process_api)
				vim.g.yazi_process_id = process_api.yazi_id
				vim.g.yazi_buffer = buffer
			end,
		},
	},
	init = function()
		vim.g.loaded_netrw = 1
		vim.g.loaded_netrwPlugin = 1
	end,
	config = function(_, opts)
		require("yazi").setup(opts)

		local binder = Keybinder.new(nil, "YAZI")
		local logger = Logger.new("YAZI")

		binder:nmap("<C-a>", function()
			local current_file = vim.api.nvim_buf_get_name(0)

			if current_file == "" then
				logger:warn("Current buffer has no file path")
				return
			end

			local ok, dir = pcall(vim.fs.dirname, current_file)

			if not ok then
				logger:warn("Invalid buffer directory")
				return
			end

			require("yazi").yazi(nil, dir)
		end, { desc = "Toggle yazi in buffer cwd" })

		binder:nmap("<C-f>", function()
			require("yazi").yazi(nil, vim.fn.getcwd())
		end, { desc = "Toggle yazi in root cwd" })
	end,
}
