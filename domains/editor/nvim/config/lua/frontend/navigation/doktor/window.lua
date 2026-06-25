local M = {}

---@type DiagnosticIcons
local icons = require("common.icons").diagnostics

local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local severity_map = {
	[vim.diagnostic.severity.ERROR] = { icon = icons.error, hl = "DiagnosticError", name = "Error" },
	[vim.diagnostic.severity.WARN] = { icon = icons.warn, hl = "DiagnosticWarn", name = "Warn" },
	[vim.diagnostic.severity.INFO] = { icon = icons.info, hl = "DiagnosticInfo", name = "Info" },
	[vim.diagnostic.severity.HINT] = { icon = icons.hint, hl = "DiagnosticHint", name = "Hint" },
}

---@param filename string
---@return string icon, string hl
local function get_file_icon(filename)
	if has_devicons then
		local ext = vim.fn.fnamemodify(filename, ":e")
		local icon, hl = devicons.get_icon(filename, ext, { default = true })
		return icon, hl
	end
	return "📄", "Normal"
end

---@return table structured_data
local function get_structured_diagnostics()
	local all_diagnostics = vim.diagnostic.get(nil)
	local grouped = {}

	for _, diag in ipairs(all_diagnostics) do
		if vim.api.nvim_buf_is_valid(diag.bufnr) then
			local full_path = vim.api.nvim_buf_get_name(diag.bufnr)
			local relative_path = vim.fn.fnamemodify(full_path, ":.")

			if not grouped[relative_path] then
				grouped[relative_path] = {
					path = relative_path,
					diagnostics = {},
				}
			end

			table.insert(grouped[relative_path].diagnostics, diag)
		end
	end

	return grouped
end

---@return integer bufnr, integer win_id
function M.render_diagnostics_window()
	local grouped_data = get_structured_diagnostics()

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].filetype = "diagnostic-menu"

	local lines = {}
	local highlights = {}

	local cwd = vim.fn.getcwd()

	table.insert(lines, cwd)

	local data_list = {}
	for _, data in pairs(grouped_data) do
		table.insert(data_list, data)
	end

	for i, data in ipairs(data_list) do
		local count = #data.diagnostics
		local file_icon, file_hl = get_file_icon(data.path)

		local is_last_file = (i == #data_list)
		local file_prefix = is_last_file and " └╴" or " ├╴"

		table.insert(lines, string.format("%s%s  %s  %d", file_prefix, file_icon, data.path, count))

		local file_icon_start = #file_prefix
		table.insert(highlights, {
			hl = file_hl,
			line = #lines - 1,
			start_col = file_icon_start,
			end_col = file_icon_start + #file_icon,
		})

		for j, diag in ipairs(data.diagnostics) do
			local sev = severity_map[diag.severity]
			local pos_str = string.format("[%d, %d]", diag.lnum + 1, diag.col + 1)

			local is_last_diag = (j == #data.diagnostics)
			local trunk = is_last_file and "    " or " │  "
			local branch = is_last_diag and "└╴" or "├╴"
			local diag_prefix = trunk .. branch

			local diag_line = string.format("%s%s  %s %s", diag_prefix, sev.icon, diag.message, pos_str)
			table.insert(lines, diag_line)

			local diag_icon_start = #diag_prefix
			table.insert(highlights, {
				hl = sev.hl,
				line = #lines - 1,
				start_col = diag_icon_start,
				end_col = diag_icon_start + #sev.icon,
			})
		end

		if not is_last_file then
			table.insert(lines, " │")
		end
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	local ns_id = vim.api.nvim_create_namespace("DiagnosticWindowIcons")
	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, hl.line, hl.start_col, {
			end_col = hl.end_col,
			hl_group = hl.hl,
			hl_mode = "combine",
		})
	end

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.6)

	local win_id = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " Project Diagnostics ",
		title_pos = "center",
	})

	return bufnr, win_id
end

return M
