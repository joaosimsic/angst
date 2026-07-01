local R = require("config.debug.render")
local M = {}

local MIN_WIDTHS = { modes = 7, lhs = 12, scope = 5, desc = 15, source = 10 }
local COL_NAMES = { "modes", "lhs", "scope", "desc", "source" }

local function layout(card_width, natural)
	natural = natural or {}
	local n = {}
	for _, name in ipairs(COL_NAMES) do
		n[name] = math.max(MIN_WIDTHS[name], natural[name] or MIN_WIDTHS[name])
	end

	local gaps = 5
	local borders = 4
	local available = card_width - gaps - borders

	local widths = {}
	local total_n = n.modes + n.lhs + n.scope + n.desc + n.source

	if total_n <= available then
		for _, name in ipairs(COL_NAMES) do
			widths[name] = math.floor(available * n[name] / total_n)
		end
		local sum = 0
		for _, name in ipairs(COL_NAMES) do
			sum = sum + widths[name]
		end
		widths.desc = widths.desc + (available - sum)
	else
		for _, name in ipairs(COL_NAMES) do
			widths[name] = MIN_WIDTHS[name]
		end
		local remaining = available
		for _, name in ipairs(COL_NAMES) do
			remaining = remaining - widths[name]
		end
		if remaining > 0 then
			local priority = { "lhs", "desc", "source" }
			local total_need = 0
			for _, name in ipairs(priority) do
				total_need = total_need + math.max(0, n[name] - MIN_WIDTHS[name])
			end
			if total_need > 0 then
				for _, name in ipairs(priority) do
					local need = math.max(0, n[name] - MIN_WIDTHS[name])
					widths[name] = widths[name] + math.floor(remaining * need / total_need)
				end
			end
		end
		local sum = 0
		for _, name in ipairs(COL_NAMES) do
			sum = sum + widths[name]
		end
		widths.desc = widths.desc + (available - sum)
	end

	local col_fmt = "| %-"
		.. widths.modes
		.. "s %-"
		.. widths.lhs
		.. "s %-"
		.. widths.scope
		.. "s %-"
		.. widths.desc
		.. "s  %-"
		.. widths.source
		.. "s |"

	local modes_start = 2
	local lhs_start = modes_start + widths.modes + 1
	local scope_start = lhs_start + widths.lhs + 1
	local desc_start = scope_start + widths.scope + 1
	local source_start = desc_start + widths.desc + 2

	return col_fmt,
		widths.modes,
		widths.lhs,
		widths.scope,
		widths.desc,
		widths.source,
		modes_start,
		lhs_start,
		scope_start,
		desc_start,
		source_start
end

local function measure_cols(entries)
	local natural = { modes = #"MODES", lhs = #"LHS", scope = #"SCOPE", desc = #"DESC/RHS", source = #"SOURCE" }
	for _, e in ipairs(entries) do
		natural.modes =
			math.max(natural.modes, vim.fn.strdisplaywidth(e.modes_str or MODE_CHARS[e._mode] or e._mode:upper()))
		natural.lhs = math.max(natural.lhs, vim.fn.strdisplaywidth(e.lhs))
		local scope = (e.buffer or 0) > 0 and "buf " .. (e.buffer or 0) or "gbl"
		natural.scope = math.max(natural.scope, #scope)
		natural.desc = math.max(natural.desc, vim.fn.strdisplaywidth(e.desc or ""))
		natural.source = math.max(natural.source, vim.fn.strdisplaywidth(e.source or "builtin"))
	end
	return natural
end

local MODE_ORDER = { "n", "i", "v", "x", "s", "o", "t", "c" }
local MODE_CHARS = {
	n = "N",
	i = "I",
	v = "V",
	x = "X",
	s = "S",
	o = "O",
	t = "T",
	c = "C",
}

local function add_table_header(view, card_width, natural, widths)
	natural = natural or {}
	if not widths then
		local _, modes_w, lhs_w, scope_w, desc_w, source_w = layout(card_width, natural)
		widths = { modes = modes_w, lhs = lhs_w, scope = scope_w, desc = desc_w, source = source_w }
	end
	local header = "| "
		.. R.str_pad("MODES", widths.modes)
		.. " " .. R.str_pad("LHS", widths.lhs)
		.. " " .. R.str_pad("SCOPE", widths.scope)
		.. " " .. R.str_pad("DESC/RHS", widths.desc)
		.. "  " .. R.str_pad("SOURCE", widths.source)
		.. " |"
	local header_nr = R.add_line(view, header)

	R.add_highlight(view, header_nr, "DebugHeader", 0, -1)

	local sep = "| " .. string.rep("-", card_width - 4) .. " |"
	local sep_nr = R.add_line(view, sep)

	R.add_highlight(view, sep_nr, "DebugBorder", 0, -1)
end

local function add_table_row(view, modes, lhs, scope, desc, source, conflict, card_width, natural, widths)
	scope = scope or "gbl"
	natural = natural or {}
	if not widths then
		local _, modes_w, lhs_w, scope_w, desc_w, source_w = layout(card_width, natural)
		widths = { modes = modes_w, lhs = lhs_w, scope = scope_w, desc = desc_w, source = source_w }
	end

	modes = R.ellipsize(modes, widths.modes)
	lhs = R.ellipsize(lhs, widths.lhs)
	scope = R.ellipsize(scope, widths.scope)
	desc = R.ellipsize(desc, widths.desc)
	source = R.ellipsize(source, widths.source)

	local col_modes = R.str_pad(modes, widths.modes)
	local col_lhs = R.str_pad(lhs, widths.lhs)
	local col_scope = R.str_pad(scope, widths.scope)
	local col_desc = R.str_pad(desc, widths.desc)
	local col_source = R.str_pad(source, widths.source)

	local line = "| "
		.. col_modes .. " " .. col_lhs .. " " .. col_scope .. " " .. col_desc
		.. "  " .. col_source .. " |"
	local line_nr = R.add_line(view, line)

	local modes_start = 2
	local lhs_start = modes_start + #col_modes + 1
	local scope_start = lhs_start + #col_lhs + 1
	local desc_start = scope_start + #col_scope + 1
	local source_start = desc_start + #col_desc + 2

	R.add_highlight(view, line_nr, "DebugBorder", 0, 1)
	R.add_highlight(view, line_nr, "DebugBorder", #line - 1, #line)

	if conflict then
		R.add_highlight(view, line_nr, "DebugWarn", modes_start, source_start + #col_source)
	else
		R.add_highlight(view, line_nr, "DebugInfo", modes_start, modes_start + #modes)
		R.add_highlight(view, line_nr, "DebugLabel", lhs_start, lhs_start + #lhs)
		R.add_highlight(
			view,
			line_nr,
			scope ~= "gbl" and "DebugInfo" or "DebugValue",
			scope_start,
			scope_start + #scope
		)
		R.add_highlight(view, line_nr, "DebugValue", desc_start, desc_start + #desc)
		R.add_highlight(view, line_nr, "DebugMuted", source_start, source_start + #source)
	end
end

local function collect_keymaps(bufnr)
	local raw = {}

	for _, mode in ipairs(MODE_ORDER) do
		for _, km in ipairs(vim.api.nvim_get_keymap(mode) or {}) do
			km._mode = mode
			table.insert(raw, km)
		end

		if bufnr then
			for _, km in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode) or {}) do
				km._mode = mode
				table.insert(raw, km)
			end
		end
	end

	return raw
end

local function build_sid_cache()
	local cache = {}
	local ok, output = pcall(vim.fn.execute, "scriptnames")

	if not ok then
		return cache
	end

	for line in output:gmatch("[^\r\n]+") do
		local sid, path = line:match("^%s*(%d+):%s*(.*)$")

		if sid then
			cache[tonumber(sid)] = path
		end
	end

	return cache
end

local function shorten_source(path)
	if not path then
		return "builtin"
	end

	local dir = vim.fn.fnamemodify(path, ":h:t")
	local file = vim.fn.fnamemodify(path, ":t")

	if dir and dir ~= "" then
		return dir .. "/" .. file
	end

	return file
end

local function format_modes(modes)
	local chars = {}

	for _, m in ipairs(MODE_ORDER) do
		if modes[m] then
			table.insert(chars, MODE_CHARS[m] or m:upper())
		end
	end

	return table.concat(chars, ",")
end

local function collapse_entries(raw, sid_cache)
	local groups = {}

	for _, km in ipairs(raw) do
		local rhs = km.rhs or ""
		local desc = (km.desc or "") ~= "" and km.desc or (rhs ~= "" and rhs or nil)
		local cb_id = km.callback and tostring(km.callback) or ""
		local key = km.lhs .. "|" .. rhs .. "|" .. (desc or "") .. "|" .. cb_id .. "|" .. km.buffer

		if not groups[key] then
			groups[key] = {
				lhs = km.lhs,
				rhs = rhs,
				desc = desc or "<lua>",
				buffer = km.buffer,
				modes = {},
				sid = km.sid,
				source = sid_cache[km.sid] and shorten_source(sid_cache[km.sid]) or "builtin",
				conflict = false,
			}
		end

		groups[key].modes[km._mode] = true
	end

	local result = {}

	for _, g in pairs(groups) do
		g.modes_str = format_modes(g.modes)
		table.insert(result, g)
	end

	table.sort(result, function(a, b)
		return a.lhs < b.lhs
	end)

	return result
end

local function detect_conflicts(collapsed, conflict_set)
	local groups = {}

	for _, entry in ipairs(collapsed) do
		local key = entry.lhs .. "|" .. entry.buffer

		if not groups[key] then
			groups[key] = {}
		end

		table.insert(groups[key], entry)
	end

	for _, group in pairs(groups) do
		if #group > 1 then
			for i = 1, #group do
				for j = i + 1, #group do
					local ei, ej = group[i], group[j]
					local shared = false

					for mode in pairs(ei.modes) do
						if ej.modes[mode] then
							shared = true
							break
						end
					end

					if shared then
						local same = ei.rhs == ej.rhs and ei.callback == ej.callback and ei.desc == ej.desc

						if not same then
							ei.conflict = true
							ej.conflict = true
							conflict_set[ei.lhs .. "|" .. ei.buffer] = true
							conflict_set[ej.lhs .. "|" .. ej.buffer] = true
						end
					end
				end
			end
		end
	end
end

local function per_mode_counts(raw)
	local counts = {}

	for _, m in ipairs(MODE_ORDER) do
		counts[m] = 0
	end

	for _, km in ipairs(raw) do
		if counts[km._mode] then
			counts[km._mode] = counts[km._mode] + 1
		end
	end

	return counts
end

local function render_summary(view, total, collapsed_count, conflict_count, per_mode, card_width)
	R.add_section(view, "Keymap Summary", card_width)
	R.add_row(
		view,
		"Keymaps",
		total,
		total > 0 and "DebugInfo" or "DebugWarn",
		{ label_width = 16, card_width = card_width }
	)
	R.add_row(view, "Collapsed", collapsed_count, "DebugValue", { label_width = 16, card_width = card_width })
	R.add_row(
		view,
		"Conflicts",
		conflict_count,
		conflict_count > 0 and "DebugWarn" or "DebugOk",
		{ label_width = 16, card_width = card_width }
	)

	local mode_parts = {}

	for _, m in ipairs(MODE_ORDER) do
		table.insert(mode_parts, MODE_CHARS[m] .. " " .. (per_mode[m] or 0))
	end

	R.add_row(
		view,
		"Per mode",
		table.concat(mode_parts, "  "),
		"DebugInfo",
		{ label_width = 16, card_width = card_width }
	)
	R.add_footer(view, card_width)
end

local function render_conflicts(view, raw, conflict_set, sid_cache, card_width)
	local conflict_raw = {}

	for _, km in ipairs(raw) do
		local key = km.lhs .. "|" .. km.buffer

		if conflict_set[key] then
			table.insert(conflict_raw, km)
		end
	end

	if #conflict_raw == 0 then
		return
	end

	table.sort(conflict_raw, function(a, b)
		if a.lhs ~= b.lhs then
			return a.lhs < b.lhs
		end

		return a.buffer < b.buffer
	end)

	R.add_section(view, "Conflicts (" .. #conflict_raw .. ")", card_width)
	R.add_gap(view)
	local natural = measure_cols(conflict_raw)
	local _, mw, lw, sw, dw, scw = layout(card_width, natural)
	local widths = { modes = mw, lhs = lw, scope = sw, desc = dw, source = scw }
	add_table_header(view, card_width, natural, widths)

	for _, km in ipairs(conflict_raw) do
		local scope = km.buffer > 0 and "buf " .. km.buffer or "gbl"
		local desc = (km.desc or "") ~= "" and km.desc or (km.rhs or "<lua>")
		local source = sid_cache[km.sid] and shorten_source(sid_cache[km.sid]) or "builtin"

		add_table_row(
			view,
			MODE_CHARS[km._mode] or km._mode:upper(),
			km.lhs,
			scope,
			desc,
			source,
			true,
			card_width,
			natural,
			widths
		)
	end

	R.add_footer(view, card_width)
end

local function render_bindings(view, collapsed, card_width)
	R.add_section(view, "Bindings (" .. #collapsed .. ")", card_width)
	R.add_gap(view)
	local natural = measure_cols(collapsed)
	local _, mw, lw, sw, dw, scw = layout(card_width, natural)
	local widths = { modes = mw, lhs = lw, scope = sw, desc = dw, source = scw }
	add_table_header(view, card_width, natural, widths)

	for _, entry in ipairs(collapsed) do
		local scope = entry.buffer > 0 and "buf " .. entry.buffer or "gbl"

		add_table_row(
			view,
			entry.modes_str,
			entry.lhs,
			scope,
			entry.desc,
			entry.source,
			entry.conflict,
			card_width,
			natural,
			widths
		)
	end

	R.add_footer(view, card_width)
end

function M.render(bufnr, card_width)
	card_width = card_width or 84
	R.set_card_width(card_width)

	local sid_cache = build_sid_cache()
	local raw = collect_keymaps(bufnr)
	local collapsed = collapse_entries(raw, sid_cache)
	local conflict_set = {}

	detect_conflicts(collapsed, conflict_set)

	local view = {
		lines = {},
		highlights = {},
	}

	render_summary(view, #raw, #collapsed, #conflict_set, per_mode_counts(raw), card_width)
	R.add_gap(view)
	render_conflicts(view, raw, conflict_set, sid_cache, card_width)
	R.add_gap(view)
	render_bindings(view, collapsed, card_width)

	return view
end

return M
