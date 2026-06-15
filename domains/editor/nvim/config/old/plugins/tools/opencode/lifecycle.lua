local M = {}

local function get_state_file()
	local cwd = vim.fn.getcwd()
	local encoded = cwd:gsub("/", "%%")
	return vim.fn.stdpath("state") .. "/opencode_state_" .. encoded
end

local function is_opencode_open()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) then
			local bufname = vim.api.nvim_buf_get_name(buf)
			if bufname:match("term://.*opencode") then
				return true
			end
		end
	end
	return false
end

local function save_opencode_state()
	local state_file = get_state_file()
	if is_opencode_open() then
		vim.fn.writefile({ "open" }, state_file)
	else
		vim.fn.delete(state_file)
	end
end

local function restore_opencode_state()
	local state_file = get_state_file()
	if vim.fn.filereadable(state_file) == 1 then
		vim.fn.delete(state_file)
		vim.defer_fn(function()
			pcall(function()
				require("opencode").toggle()
			end)
		end, 100)
	end
end

local function stop_opencode_cleanly()
	pcall(require("opencode.events").unsubscribe)

	pcall(require("opencode.provider").stop)

	vim.schedule(function()
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(buf) then
				local bufname = vim.api.nvim_buf_get_name(buf)
				if bufname:match("term://.*opencode") then
					local chan = vim.bo[buf].channel
					if chan and chan > 0 then
						pcall(vim.fn.jobstop, chan)
					end
					pcall(vim.api.nvim_buf_delete, buf, { force = true })
				end
			end
		end
	end)
end

function M.setup()
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			save_opencode_state()
			stop_opencode_cleanly()
		end,
		desc = "Save OpenCode state and stop cleanly before Neovim exit",
	})

	vim.api.nvim_create_autocmd("QuitPre", {
		callback = function()
			local windows = vim.api.nvim_list_wins()
			local non_floating_windows = vim.tbl_filter(function(win)
				local config = vim.api.nvim_win_get_config(win)
				return not config.relative or config.relative == ""
			end, windows)

			if #non_floating_windows <= 1 then
				save_opencode_state()
				stop_opencode_cleanly()
			end
		end,
		desc = "Stop OpenCode when quitting last window",
	})

	vim.api.nvim_create_autocmd("VimEnter", {
		callback = function()
			vim.defer_fn(function()
				restore_opencode_state()
			end, 500)
		end,
		desc = "Restore OpenCode state on Neovim start",
	})
end

function M.stop()
	stop_opencode_cleanly()
	vim.notify("OpenCode stopped", vim.log.levels.INFO)
end

return M
