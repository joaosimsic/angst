---@type DoktorCacheState
local State = require("frontend.navigation.doktor.state")

---@type DiagnosticIcons
local icons = require("common.icons").diagnostics
---@type Logger
local logger = require("frontend.navigation.doktor.logger")

local M = {}

---@type boolean
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

---@class DoktorTreeHighlight
---@field hl string
---@field line integer
---@field start_col integer
---@field end_col integer

---@type table<vim.diagnostic.Severity, {icon: string, hl: string}>
local severity_map = {
	[vim.diagnostic.severity.ERROR] = { icon = icons.error, hl = "DiagnosticError" },
	[vim.diagnostic.severity.WARN] = { icon = icons.warn, hl = "DiagnosticWarn" },
	[vim.diagnostic.severity.INFO] = { icon = icons.info, hl = "DiagnosticInfo" },
	[vim.diagnostic.severity.HINT] = { icon = icons.hint, hl = "DiagnosticHint" },
}

---@param filename string
---@return string
---@return string
local function get_file_icon(filename)
	if has_devicons then
		---@type string
		local ext = vim.fn.fnamemodify(filename, ":e")
		---@type string, string, string
		local icon, hl = devicons.get_icon(filename, ext, { default = true })
		return icon, hl
	end
	return "📄", "Normal"
end

---@param data_list DoktorGroupedFile[]
---@return string[]
---@return DoktorTreeHighlight[]
function M.build_tree_view(data_list)
	---@type string[]
	local lines = { "." }
	---@type DoktorTreeHighlight[]
	local highlights = {}

	State.row_map = {}

	for i, data in ipairs(data_list) do
		---@type integer
		local total_count = #data.diagnostics
		---@type string
		local file_icon
		---@type string
		local file_hl
		file_icon, file_hl = get_file_icon(data.path)
		---@type boolean
		local is_last_file = (i == #data_list)
		---@type string
		local file_prefix = is_last_file and " └╴" or " ├╴"

		table.insert(lines, string.format("%s%s  %s  %d", file_prefix, file_icon, data.path, total_count))
		table.insert(highlights, {
			hl = file_hl,
			line = #lines - 1,
			start_col = #file_prefix,
			end_col = #file_prefix + #file_icon,
		})

		for j, line_data in ipairs(data.sorted_lines) do
			---@type boolean
			local is_last_line_group = (j == #data.sorted_lines)
			---@type string
			local file_trunk = is_last_file and "    " or " │  "
			---@type string
			local position_branch = is_last_line_group and "└╴" or "├╴"

			---@type string
			local pos_str = string.format("[%d, %d]", line_data.lnum + 1, line_data.col + 1)
			table.insert(lines, string.format("%s%s%s", file_trunk, position_branch, pos_str))

			---@type string
			local diagnostic_trunk = file_trunk .. (is_last_line_group and "     " or "│    ")

			for k, diag in ipairs(line_data.diags) do
				---@type boolean
				local is_last_diag = (k == #line_data.diags)
				---@type string
				local diag_branch = is_last_diag and "└╴" or "├╴"
				---@type {icon: string, hl: string}
				local sev = severity_map[diag.severity] or severity_map[vim.diagnostic.severity.HINT]

				---@type string[]
				local msg_lines = vim.split(diag.message or "", "\n", { plain = true })
				for idx, msg_line in ipairs(msg_lines) do
					if idx == 1 then
						table.insert(
							lines,
							string.format("%s%s%s  %s", diagnostic_trunk, diag_branch, sev.icon, msg_line)
						)

						---@type integer
						local current_line_idx = #lines
						---@type DoktorDiagnosticItem
						State.row_map[current_line_idx] = {
							filename = data.path,
							lnum = line_data.lnum,
							col = line_data.col,
							message = diag.message or "",
							severity = sev.hl,
						}

						table.insert(highlights, {
							hl = sev.hl,
							line = current_line_idx - 1,
							start_col = #diagnostic_trunk + #diag_branch,
							end_col = #diagnostic_trunk + #diag_branch + #sev.icon,
						})
					else
						---@type string
						local extra_trunk = is_last_diag and "    " or "│   "
						table.insert(lines, string.format("%s%s   %s", diagnostic_trunk, extra_trunk, msg_line))

						---@type DoktorDiagnosticItem
						State.row_map[#lines] = {
							filename = data.path,
							lnum = line_data.lnum,
							col = line_data.col,
							message = diag.message or "",
							severity = sev.hl,
						}
					end
				end
			end
		end

		if not is_last_file then
			table.insert(lines, " │")
		end
	end

	logger:debug(function()
		return string.format("Tree view built: %d files, %d lines", #data_list, #lines)
	end)

	return lines, highlights
end

return M
