local Keybinder = require("common.Keybinder")
local Logger = require("common.Logger")
local display = require("frontend.tools.ask.display")
local api = require("frontend.tools.ask.api")

local log = Logger.new("ask", "debug")

local active_cleanup = nil

local M = {}

function M.ask(opts)
	local bufnr = vim.api.nvim_get_current_buf()

	local start_line_1idx, end_line_1idx

	if opts and opts.visual then
		vim.cmd("normal! \x1b")
		local s_start = vim.fn.getpos("'<")
		local s_end = vim.fn.getpos("'>")
		start_line_1idx = s_start[2]
		end_line_1idx = s_end[2]
	else
		local cursor = vim.api.nvim_win_get_cursor(0)
		start_line_1idx = cursor[1]
		end_line_1idx = cursor[1]
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	end_line_1idx = math.min(end_line_1idx, line_count)
	start_line_1idx = math.max(1, math.min(start_line_1idx, end_line_1idx))

	log:info(string.format("start=%d end=%d line_count=%d",
		start_line_1idx, end_line_1idx, line_count))

	local buf_lines = vim.api.nvim_buf_get_lines(bufnr, start_line_1idx - 1, end_line_1idx, false)
	local numbered_lines = {}
	for i, line in ipairs(buf_lines) do
		table.insert(numbered_lines, string.format("%3d | %s", start_line_1idx + i - 1, line))
	end
	local numbered_code = table.concat(numbered_lines, "\n")

	local extmark_line = math.min(end_line_1idx - 1, math.max(0, line_count - 1))

	local orig_filetype = vim.bo[bufnr].filetype
	vim.diagnostic.enable(false, { bufnr = bufnr })
	vim.bo[bufnr].filetype = ""

	vim.api.nvim_buf_clear_namespace(bufnr, display.ns_id, 0, -1)

	local _, prompt_extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
		virt_lines = {
			{ { display.get_indent(bufnr, extmark_line) .. "Prompt: ", "Comment" } },
		},
	})

	local input_line = extmark_line + 1
	vim.api.nvim_buf_set_lines(bufnr, input_line, input_line, false, { "" })
	vim.api.nvim_win_set_cursor(0, { input_line + 1, 0 })

	local function cleanup()
		pcall(vim.api.nvim_buf_del_extmark, bufnr, display.ns_id, prompt_extmark_id)
		pcall(vim.api.nvim_buf_set_lines, bufnr, input_line, input_line + 1, false, {})
		pcall(vim.api.nvim_buf_del_keymap, bufnr, 'i', '<CR>')
		pcall(vim.api.nvim_buf_del_keymap, bufnr, 'i', '<Esc>')
		vim.bo[bufnr].filetype = orig_filetype
		vim.diagnostic.enable(true, { bufnr = bufnr })
		active_cleanup = nil
	end
	active_cleanup = cleanup

	local function cancel()
		vim.cmd("stopinsert")
		cleanup()
	end

	vim.keymap.set('i', '<CR>', function()
		vim.cmd("stopinsert")
		local lines = vim.api.nvim_buf_get_lines(bufnr, input_line, input_line + 1, false)
		local input = vim.trim(lines[1] or "")
		cleanup()

		if input == "" then
			return
		end

		api.submit({
			bufnr = bufnr,
			extmark_line = extmark_line,
			start_line_1idx = start_line_1idx,
			end_line_1idx = end_line_1idx,
			numbered_code = numbered_code,
			input = input,
		})
	end, { buffer = bufnr, noremap = true, silent = true })

	vim.keymap.set('i', '<Esc>', cancel, { buffer = bufnr, noremap = true, silent = true })

	vim.cmd("startinsert")
end

function M.dismiss()
	if active_cleanup then
		active_cleanup()
	end
	display.clear()
end

return {
	"ask",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local binder = Keybinder.new(nil, "ASK")
		binder:set_debug(true)
		binder:nmap("<leader>m", M.ask, { desc = "Ask about code" })
		binder:vmap("<leader>m", function() M.ask({ visual = true }) end, { desc = "Ask about code" })
		binder:nmap("<leader>q", M.dismiss, { desc = "Dismiss ask response" })
	end,
}
