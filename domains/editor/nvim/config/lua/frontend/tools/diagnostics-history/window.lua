---@type Keybinder
local Keybinder = require("common.Keybinder")
local icons = require("common.icons")
local layout = require("frontend.tools.diagnostics-history.layout")

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

---@param row table
---@param expanded? boolean
---@return string
local function row_text(row, expanded)
	local indent = string.rep("  ", row.indent or 0)
	if row.kind == "separator" then
		return "── " .. row.label .. " ──"
	elseif row.kind == "folder" then
		return indent .. "▾ " .. (expanded and row.dir or row.name) .. "/"
	elseif row.kind == "file" then
		return indent .. "▸ " .. row.label
	elseif row.kind == "line" then
		return indent .. row.label .. ":"
	elseif row.kind == "diagnostic" then
		local item = row.item
		local icon = severity_icons[item.severity] or "?"
		local source = ""
		if item.source ~= nil and item.source ~= "" then
			source = "[" .. item.source .. "] "
		end
		return indent .. icon .. " " .. tostring(item.col + 1) .. ": " .. source .. sanitize(item.message or "")
	end
	return ""
end

---@param item table
local function copy_item(item)
	local label = severity_labels[item.severity] or "?"
	local bufname = vim.api.nvim_buf_get_name(item.bufnr)
	local text = string.format(
		"[%s] %s:%d:%d  %s  %s",
		label,
		bufname,
		item.lnum + 1,
		item.col + 1,
		item.source or "",
		item.message
	)
	vim.fn.setreg("+", text)
	vim.notify(string.format("Copied: %s", text), vim.log.levels.INFO)
end

---@param items table[]
local function copy_all(items)
	local lines = {}
	for _, item in ipairs(items) do
		local label = severity_labels[item.severity] or "?"
		local bufname = vim.api.nvim_buf_get_name(item.bufnr)
		table.insert(
			lines,
			string.format(
				"[%s] %s:%d:%d  %s  %s",
				label,
				bufname,
				item.lnum + 1,
				item.col + 1,
				item.source or "",
				item.message
			)
		)
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

	local current_bufnr = vim.api.nvim_get_current_buf()
	local rows = layout.build(items, current_bufnr, vim.fn.getcwd())

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
	vim.bo[buf_handle].bufhidden = "wipe"
	vim.wo[win_handle].cursorline = true
	vim.wo[win_handle].number = false
	vim.wo[win_handle].relativenumber = false

	local rowmap = {}
	local folder_rows = {}
	local ordered_items = {}
	local lines = {}
	for i, item in ipairs(rows) do
		lines[i] = row_text(item, false)
		if item.kind == "diagnostic" then
			rowmap[i] = item.item
			ordered_items[#ordered_items + 1] = item.item
		elseif item.kind == "folder" then
			folder_rows[item.dir] = i
		end
	end

	vim.api.nvim_buf_set_lines(buf_handle, 0, -1, false, lines)

	for i, item in ipairs(rows) do
		if item.kind == "diagnostic" then
			local indent = string.rep("  ", item.indent or 0)
			local icon = severity_icons[item.item.severity] or "?"
			vim.api.nvim_buf_set_extmark(buf_handle, ns_id, i - 1, #indent, {
				end_col = #indent + #icon,
				hl_group = severity_colors[item.item.severity],
				priority = 100,
			})
		end
	end
	vim.bo[buf_handle].modifiable = false

	local expanded_folder = nil
	local function update_hover()
		if not (win_handle and vim.api.nvim_win_is_valid(win_handle)) then
			return
		end
		if not (buf_handle and vim.api.nvim_buf_is_valid(buf_handle)) then
			return
		end
		local ok, cursor = pcall(vim.api.nvim_win_get_cursor, win_handle)
		if not ok then
			return
		end
		local meta = rows[cursor[1]]
		local folder = nil
		if meta ~= nil then
			if meta.kind == "folder" then
				folder = meta.dir
			else
				folder = meta.group
			end
		end
		if folder == expanded_folder then
			return
		end
		local previous = expanded_folder
		expanded_folder = folder
		local function relabel(dir, expanded)
			local index = folder_rows[dir]
			if index == nil then
				return
			end
			local folder_meta = rows[index]
			if folder_meta == nil or folder_meta.kind ~= "folder" then
				return
			end
			vim.bo[buf_handle].modifiable = true
			pcall(vim.api.nvim_buf_set_lines, buf_handle, index - 1, index, false, { row_text(folder_meta, expanded) })
			vim.bo[buf_handle].modifiable = false
		end
		if previous ~= nil then
			relabel(previous, false)
		end
		if folder ~= nil then
			relabel(folder, true)
		end
	end
	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = buf_handle,
		callback = update_hover,
	})
	update_hover()

	local function item_at_cursor()
		if not (win_handle and vim.api.nvim_win_is_valid(win_handle)) then
			return nil
		end
		local cursor = vim.api.nvim_win_get_cursor(win_handle)
		return rowmap[cursor[1]]
	end

	local binder = Keybinder.new(buf_handle, "DIAGNOSTICS-HISTORY")
	binder:nmap("q", close, { desc = "Close diagnostics history" })
	binder:nmap("<Esc>", close, { desc = "Close diagnostics history" })
	binder:nmap("y", function()
		local item = item_at_cursor()
		if item ~= nil then
			copy_item(item)
		end
	end, { desc = "Copy diagnostic entry" })
	binder:nmap("Y", function()
		copy_all(ordered_items)
	end, { desc = "Copy all diagnostics" })
	binder:nmap("<CR>", function()
		local item = item_at_cursor()
		if item ~= nil then
			copy_item(item)
		end
	end, { desc = "Copy diagnostic entry" })
	binder:nmap("d", function()
		state.items = {}
		state.keys = {}
		close()
		vim.notify("Diagnostics history cleared", vim.log.levels.INFO)
	end, { desc = "Clear diagnostics history" })
	binder:nmap("g", function()
		local item = item_at_cursor()
		if item ~= nil then
			close()
			pcall(vim.api.nvim_set_current_buf, item.bufnr)
			pcall(vim.api.nvim_win_set_cursor, 0, { item.lnum + 1, item.col })
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
