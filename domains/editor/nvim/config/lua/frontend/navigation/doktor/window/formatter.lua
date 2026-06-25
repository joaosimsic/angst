local M = {}
---@type DiagnosticIcons
local icons = require("common.icons").diagnostics

local has_devicons, devicons = pcall(require, "nvim-web-devicons")

---@type DoktorCacheState
local State = require("frontend.navigation.doktor.state")

local severity_map = {
	[vim.diagnostic.severity.ERROR] = { icon = icons.error, hl = "DiagnosticError" },
	[vim.diagnostic.severity.WARN] = { icon = icons.warn, hl = "DiagnosticWarn" },
	[vim.diagnostic.severity.INFO] = { icon = icons.info, hl = "DiagnosticInfo" },
	[vim.diagnostic.severity.HINT] = { icon = icons.hint, hl = "DiagnosticHint" },
}

local function get_file_icon(filename)
	if has_devicons then
		local ext = vim.fn.fnamemodify(filename, ":e")
		return devicons.get_icon(filename, ext, { default = true })
	end
	return "📄", "Normal"
end

local function find_flat_item(path, lnum, col)
	local items = State.items or {}
	for _, item in ipairs(items) do
		if item.filename == path and item.lnum == lnum and item.col == col then
			return item
		end
	end
	return nil
end

function M.build_tree_view(data_list)
	local lines = { vim.fn.getcwd() }
	local highlights = {}

	State.row_map = {}

	for i, data in ipairs(data_list) do
		local total_count = #data.diagnostics
		local file_icon, file_hl = get_file_icon(data.path)
		local is_last_file = (i == #data_list)
		local file_prefix = is_last_file and " └╴" or " ├╴"

		table.insert(lines, string.format("%s%s  %s  %d", file_prefix, file_icon, data.path, total_count))
		table.insert(highlights, {
			hl = file_hl,
			line = #lines - 1,
			start_col = #file_prefix,
			end_col = #file_prefix + #file_icon,
		})

		for j, line_data in ipairs(data.sorted_lines) do
			local is_last_line_group = (j == #data.sorted_lines)
			local file_trunk = is_last_file and "    " or " │  "
			local position_branch = is_last_line_group and "└╴" or "├╴"

			local pos_str = string.format("[%d, %d]", line_data.lnum + 1, line_data.col + 1)
			table.insert(lines, string.format("%s%s%s", file_trunk, position_branch, pos_str))

			local diagnostic_trunk = file_trunk .. (is_last_line_group and "     " or "│    ")

			for k, diag in ipairs(line_data.diags) do
				local is_last_diag = (k == #line_data.diags)
				local diag_branch = is_last_diag and "└╴" or "├╴"
				local sev = severity_map[diag.severity] or severity_map[vim.diagnostic.severity.HINT]

				local msg_lines = vim.split(diag.message or "", "\n", { plain = true })
				for idx, msg_line in ipairs(msg_lines) do
					if idx == 1 then
						table.insert(
							lines,
							string.format("%s%s%s  %s", diagnostic_trunk, diag_branch, sev.icon, msg_line)
						)

						local current_line_idx = #lines
						local flat_item = find_flat_item(data.path, line_data.lnum, line_data.col)
						if flat_item then
							State.row_map[current_line_idx] = flat_item
						end

						table.insert(highlights, {
							hl = sev.hl,
							line = current_line_idx - 1,
							start_col = #diagnostic_trunk + #diag_branch,
							end_col = #diagnostic_trunk + #diag_branch + #sev.icon,
						})
					else
						local extra_trunk = is_last_diag and "    " or "│   "
						table.insert(lines, string.format("%s%s   %s", diagnostic_trunk, extra_trunk, msg_line))
					end
				end
			end
		end

		if not is_last_file then
			table.insert(lines, " │")
		end
	end

	return lines, highlights
end

return M
