---@type Logger
local Logger = require("common.Logger")
local Window = require("frontend.tools.diagnostics-history.window")

local M = {}

local state = {
	items = {},
	keys = {},
	logger = Logger.new("DIAGNOSTIC-HISTORY"),
}

local function make_key(diag, bufnr)
	return string.format("%d:%d:%d:%d:%s", bufnr, diag.lnum, diag.col, diag.severity, vim.trim(diag.message))
end

local function make_item(diag, bufnr, key)
	return {
		bufnr = bufnr,
		lnum = diag.lnum,
		col = diag.col,
		end_lnum = diag.end_lnum,
		end_col = diag.end_col,
		severity = diag.severity,
		message = diag.message,
		source = diag.source,
		code = diag.code,
		key = key,
	}
end

local function sync_buffer_diagnostics(bufnr)
	local current = vim.diagnostic.get(bufnr)
	local current_by_key = {}
	for _, diag in ipairs(current) do
		current_by_key[make_key(diag, bufnr)] = diag
	end

	local new_items = {}
	local new_keys = {}
	for _, item in ipairs(state.items) do
		if item.bufnr == bufnr then
			local diag = current_by_key[item.key]
			if diag then
				table.insert(new_items, item)
				new_keys[item.key] = true
				current_by_key[item.key] = nil
			end
		else
			table.insert(new_items, item)
			new_keys[item.key] = true
		end
	end

	for key, diag in pairs(current_by_key) do
		new_keys[key] = true
		table.insert(new_items, make_item(diag, bufnr, key))
	end

	state.items = new_items
	state.keys = new_keys
end

local function remove_buffer(bufnr)
	local new_items = {}
	local new_keys = {}
	for _, item in ipairs(state.items) do
		if item.bufnr ~= bufnr then
			table.insert(new_items, item)
			new_keys[item.key] = true
		end
	end
	state.items = new_items
	state.keys = new_keys
end

function M.get_items()
	return state.items
end

function M.get_count()
	return #state.items
end

function M.toggle_window()
	Window.toggle(state)
end

function M.clear()
	state.items = {}
	state.keys = {}
	Window.close()
end

M.spec = {
	"diagnostics-history",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local group = vim.api.nvim_create_augroup("DiagnosticsHistory", { clear = true })

		vim.api.nvim_create_autocmd("DiagnosticChanged", {
			group = group,
			callback = function(args)
				sync_buffer_diagnostics(args.buf)
			end,
		})

		vim.api.nvim_create_autocmd("BufWipeout", {
			group = group,
			callback = function(args)
				remove_buffer(args.buf)
			end,
		})

		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(bufnr) then
				sync_buffer_diagnostics(bufnr)
			end
		end
	end,
}

return M
