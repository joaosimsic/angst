---@class TargetBufferDiag
---@field bufnr integer
---@field lnum integer
---@field col integer

local M = {}

---@param bind_callback fun(buf: integer, win: integer, target: TargetBufferDiag[])?
function M.open_panel(bind_callback)
	---@type Icons
	local icons = require("common.icons")

	local diagnostics = vim.diagnostic.get(nil)

	if #diagnostics == 0 then
		print("No workspace diagnostics found!")
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)

	local lines = {}

	---@type TargetBufferDiag[]
	local targets = {}

	for _, d in ipairs(diagnostics) do
		if d.severity == vim.diagnostic.severity.ERROR or d.severity == vim.diagnostic.severity.WARN then
			local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(d.bufnr), ":.")
			if filename == "" then
				filename = "Unknown File"
			end

			local sev_icon = d.severity == vim.diagnostic.severity.ERROR and (icons.diagnostics.error or "[E]")
				or (icons.diagnostics.warn or "[W]")

			local line_text = string.format(" %s %s:%d:%d - %s", sev_icon, filename, d.lnum + 1, d.col + 1, d.message)

			table.insert(lines, line_text)
			table.insert(targets, { bufnr = d.bufnr, lnum = d.lnum, col = d.col })
		end
	end

	if #lines == 0 then
		print("No errors or warnings found!")
		return
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = math.floor(vim.o.columns * 0.85)
	local height = math.floor(vim.o.lines * 0.6)

	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " Doktor Panel ",
		title_pos = "center",
	}

	local win = vim.api.nvim_open_win(buf, true, win_opts)

	if bind_callback then
		bind_callback(buf, win, targets)
	end
end

return M
