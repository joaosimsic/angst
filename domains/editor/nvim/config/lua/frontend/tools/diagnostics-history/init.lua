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

local function collect_buffer_diagnostics(bufnr)
	local diagnostics = vim.diagnostic.get(bufnr)
	for _, diag in ipairs(diagnostics) do
		local key = make_key(diag, bufnr)
		if not state.keys[key] then
			state.keys[key] = true
			table.insert(state.items, {
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
			})
		end
	end
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
				collect_buffer_diagnostics(args.buf)
			end,
		})

		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(bufnr) then
				collect_buffer_diagnostics(bufnr)
			end
		end
	end,
}

return M
