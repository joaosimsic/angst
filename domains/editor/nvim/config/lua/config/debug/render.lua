local M = {}

local DEFAULT_CARD_WIDTH = 84
local current_card_width = DEFAULT_CARD_WIDTH

---@param width integer
function M.set_card_width(width)
	current_card_width = width or DEFAULT_CARD_WIDTH
end

---@param view { lines: string[], highlights: table[] }
---@param line integer
---@param group string
---@param start_col integer
---@param end_col integer
function M.add_highlight(view, line, group, start_col, end_col)
	table.insert(view.highlights, {
		line = line,
		group = group,
		start_col = start_col,
		end_col = end_col,
	})
end

---@param view { lines: string[], highlights: table[] }
---@param text string
---@return integer line_nr
function M.add_line(view, text)
	table.insert(view.lines, text)
	return #view.lines
end

---@param view { lines: string[], highlights: table[] }
function M.add_gap(view)
	M.add_line(view, "")
end

---@param value any
---@param width integer
---@return string
function M.ellipsize(value, width)
	value = tostring(value or "")

	if vim.fn.strdisplaywidth(value) <= width then
		return value
	end

	if width <= 3 then
		return vim.fn.strcharpart(value, 0, width)
	end

	local dw = width - 1
	while dw > 0 do
		local s = vim.fn.strcharpart(value, 0, dw)
		if #s + 3 <= width then
			return s .. "…"
		end
		dw = dw - 1
	end

	return "…"
end

---@param view { lines: string[], highlights: table[] }
---@param title string
---@param card_width? integer
function M.add_section(view, title, card_width)
	card_width = card_width or current_card_width

	local prefix = "+-- " .. title .. " "
	local line = prefix .. string.rep("-", math.max(0, card_width - #prefix - 1)) .. "+"
	local line_nr = M.add_line(view, line)

	M.add_highlight(view, line_nr, "DebugBorder", 0, -1)
	M.add_highlight(view, line_nr, "DebugHeader", 4, 4 + #title)
end

---@param view { lines: string[], highlights: table[] }
---@param card_width? integer
function M.add_footer(view, card_width)
	card_width = card_width or current_card_width

	local line_nr = M.add_line(view, "+" .. string.rep("-", card_width - 2) .. "+")

	M.add_highlight(view, line_nr, "DebugBorder", 0, -1)
end

---@param view { lines: string[], highlights: table[] }
---@param label string
---@param value string
---@param value_hl? string
---@param opts? { label_width?: integer, card_width?: integer }
function M.add_row(view, label, value, value_hl, opts)
	opts = opts or {}

	local label_width = opts.label_width or 20
	local card_width = opts.card_width or current_card_width
	local value_width = math.max(1, card_width - label_width - 5)

	label = M.ellipsize(label, label_width)
	value = M.ellipsize(value, value_width)

	local line = "| "
		.. label
		.. string.rep(" ", label_width - #label)
		.. " "
		.. value
		.. string.rep(" ", value_width - #value)
		.. " |"
	local line_nr = M.add_line(view, line)
	local value_start = 2 + label_width + 1

	M.add_highlight(view, line_nr, "DebugBorder", 0, 1)
	M.add_highlight(view, line_nr, "DebugBorder", #line - 1, #line)
	M.add_highlight(view, line_nr, "DebugLabel", 2, 2 + #label)
	M.add_highlight(view, line_nr, value_hl or "DebugValue", value_start, value_start + #value)
end

---@param s string
---@param width integer
---@return string
function M.str_pad(s, width)
	local dw = vim.fn.strdisplaywidth(s)
	if dw >= width then
		return s
	end
	return s .. string.rep(" ", width - dw)
end

---@param values table|nil
---@param none? string
---@return string
function M.join_or_none(values, none)
	if not values or #values == 0 then
		return none or "none"
	end

	return table.concat(values, ", ")
end

return M
