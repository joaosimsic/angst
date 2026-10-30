---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Logger
local Logger = require("common.Logger")

local office_extensions = {
	doc = true,
	docx = true,
	docm = true,
	dot = true,
	dotx = true,
	dotm = true,
	odt = true,
	ott = true,
	rtf = true,
	xls = true,
	xlsx = true,
	xlsm = true,
	xlt = true,
	xltx = true,
	xltm = true,
	ods = true,
	ots = true,
	csv = true,
	ppt = true,
	pptx = true,
	pptm = true,
	pot = true,
	potx = true,
	potm = true,
	odp = true,
	otp = true,
}

---@type Plugin
return {
	"mikavilpas/yazi.nvim",
	version = "*",
	event = "VeryLazy",
	opts = {
		open_for_directories = false,
		open_file_function = function(chosen_file, config, state)
			local extension = vim.fn.fnamemodify(chosen_file, ":e"):lower()

			if office_extensions[extension] then
				vim.ui.open(chosen_file)
				return
			end

			require("yazi.openers").open_file(chosen_file, config, state)
		end,
		keymaps = {
			show_help = "<f1>",
		},
		hooks = {
			yazi_opened = function()
				vim.g.yazi_process_id = nil
				vim.g.yazi_buffer = nil
			end,
			on_yazi_ready = function(buffer, config, process_api)
				vim.g.yazi_process_id = process_api.yazi_id
				vim.g.yazi_buffer = buffer

				vim.schedule(function()
					vim.api.nvim_exec_autocmds("User", {
						pattern = "YaziReady",
						data = {
							buffer = buffer,
							yazi_id = process_api.yazi_id,
						},
					})
				end)
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
			local dir = vim.fn.getcwd()

			if current_file ~= "" then
				local ok, result = pcall(vim.fs.dirname, current_file)
				if ok then
					dir = result
				end
			end

			require("yazi").yazi(nil, dir)
		end, { desc = "Toggle yazi in buffer cwd" })

		binder:nmap("<C-f>", function()
			require("yazi").yazi(nil, vim.fn.getcwd())
		end, { desc = "Toggle yazi in root cwd" })
	end,
}
