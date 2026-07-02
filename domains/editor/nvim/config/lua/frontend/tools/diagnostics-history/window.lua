---@type Keybinder
local Keybinder = require("common.Keybinder")
local icons = require("common.icons")

local M = {}

local win_handle = nil
local buf_handle = nil

local severity_icons = {
	[vim.diagnostic.severity.ERROR] = icons.diagnostics.error,
	[vim.diagnostic.severity.WARN] = icons.diagnostics.warn,
	[vim.diagnostic.severity.INFO] = icons.diagnostics.info,
	[vim.diagnostic.severity.HINT] = icons.diagnostics.hint,
}

local severity_labels = {
	[vim.diagnostic.severity.ERROR] = "ERROR",
	[vim.diagnostic.severity.WARN] = "WARN",
	[vim.diagnostic.severity.INFO] = "INFO",
	[vim.diagnostic.severity.HINT] = "HINT",
}

local severity_colors = {
	[vim.diagnostic.severity.ERROR] = "DiagnosticError",
	[vim.diagnostic.severity.WARN] = "DiagnosticWarn",
	[vim.diagnostic.severity.INFO] = "DiagnosticInfo",
	[vim.diagnostic.severity.HINT] = "DiagnosticHint",
}

local ns_id = vim.api.nvim_create_namespace("DiagnosticsHistoryWindow")

local function sanitize(msg)
	return msg:gsub("\n", " "):gsub("\r", " ")
end

---@param item table
local function copy_item(item)
	local label = severity_labels[item.severity] or "?"
	local bufname = vim.api.nvim_buf_get_name(item.bufnr)
	local text = string.format("[%s] %s:%d:%d  %s  %s", label, bufname, item.lnum + 1, item.col + 1, item.source or "", item.message)
	vim.fn.setreg("+", text)
	vim.notify(string.format("Copied: %s", text), vim.log.levels.INFO)
end

---@param items table[]
local function copy_all(items)
	local lines = {}
	for _, item in ipairs(items) do
		local label = severity_labels[item.severity] or "?"
		local bufname = vim.api.nvim_buf_get_name(item.bufnr)
		table.insert(lines, string.format("[%s] %s:%d:%d  %s  %s", label, bufname, item.lnum + 1, item.col + 1, item.source or "", item.message))
	end
	local text = table.concat(lines, "\n")
	vim.fn.setreg("+", text)
	vim.notify(string.format("Copied %d diagnostics", #lines), vim.log.levels.INFO)
end

local function close()
	if win_handle and vim.api.nvim_win_is_valid(win_handle) then
		vim.api.nvim_win_close(win_handle, true)
	end
	win_handle = nil
	buf_handle = nil
end

function M.close()
	close()
end

---@param state { items: table[], keys: table<string, boolean> }
function M.toggle(state)
	if win_handle and vim.api.nvim_win_is_valid(win_handle) then
		close()
		return
	end

	local items = state.items
	if #items == 0 then
		vim.notify("No diagnostics in history", vim.log.levels.INFO)
		return
	end

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.6)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	buf_handle = vim.api.nvim_create_buf(false, true)
	win_handle = vim.api.nvim_open_win(buf_handle, true, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		border = "rounded",
		title = " Diagnostics History ",
		title_pos = "center",
		style = "minimal",
	})

	vim.bo[buf_handle].filetype = "DiagnosticsHistory"
	vim.wo[win_handle].cursorline = true
	vim.wo[win_handle].number = true

	local lines = {}
	for _, item in ipairs(items) do
		local icon = severity_icons[item.severity] or "?"
		local bufname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(item.bufnr), ":.")
		table.insert(lines, string.format("%s %s:%d:%d  %s", icon, bufname, item.lnum + 1, item.col + 1, sanitize(item.message)))
	end

	vim.api.nvim_buf_set_lines(buf_handle, 0, -1, false, lines)

	for i, item in ipairs(items) do
		local icon = severity_icons[item.severity] or "?"
		local icon_len = vim.fn.strchars(icon)
		vim.api.nvim_buf_set_extmark(buf_handle, ns_id, i - 1, 0, {
			end_col = icon_len,
			hl_group = severity_colors[item.severity],
			priority = 100,
		})
	end

	local binder = Keybinder.new(buf_handle, "DIAGNOSTICS-HISTORY")
	binder:nmap("q", close, { desc = "Close diagnostics history" })
	binder:nmap("<Esc>", close, { desc = "Close diagnostics history" })
	binder:nmap("y", function()
		local cursor = vim.api.nvim_win_get_cursor(win_handle)
		local idx = cursor[1]
		if idx >= 1 and idx <= #items then
			copy_item(items[idx])
		end
	end, { desc = "Copy diagnostic entry" })
	binder:nmap("Y", function()
		copy_all(items)
	end, { desc = "Copy all diagnostics" })
	binder:nmap("<CR>", function()
		local cursor = vim.api.nvim_win_get_cursor(win_handle)
		local idx = cursor[1]
		if idx >= 1 and idx <= #items then
			copy_item(items[idx])
		end
	end, { desc = "Copy diagnostic entry" })
	binder:nmap("d", function()
		state.items = {}
		state.keys = {}
		close()
		vim.notify("Diagnostics history cleared", vim.log.levels.INFO)
	end, { desc = "Clear diagnostics history" })
	binder:nmap("g", function()
		local cursor = vim.api.nvim_win_get_cursor(win_handle)
		local idx = cursor[1]
		if idx >= 1 and idx <= #items then
			local item = items[idx]
			pcall(vim.api.nvim_set_current_buf, item.bufnr)
			pcall(vim.api.nvim_win_set_cursor, 0, { item.lnum + 1, item.col })
			close()
		end
	end, { desc = "Jump to diagnostic location" })
end

vim.api.nvim_create_autocmd("WinClosed", {
	pattern = "*",
	callback = function(args)
		if win_handle and args.match == tostring(win_handle) then
			win_handle = nil
			buf_handle = nil
		end
	end,
})

return M
