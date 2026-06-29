local Logger = require("common.Logger")

local M = {}

local TAG_WIDTH = 24
local LEVEL_WIDTH = 5

local level_highlights = {
	debug = "DebugMuted",
	info = "DebugInfo",
	warn = "DebugWarn",
	error = "ErrorMsg",
}

local function is_logger_message(line)
	return line:match("^%[[^%]]+%] DEBUG: ")
		or line:match("^%[[^%]]+%] INFO: ")
		or line:match("^%[[^%]]+%] WARN: ")
		or line:match("^%[[^%]]+%] ERROR: ")
end

local function startup_level(line)
	local lower = line:lower()

	if line:match("^E%d+:") or lower:find("error", 1, true) then
		return "error"
	end

	if line:match("^W%d+:") or lower:find("warning", 1, true) or lower:find("warn", 1, true) then
		return "warn"
	end

	return "info"
end

local function startup_entries()
	local output = ""
	local ok, messages = pcall(vim.api.nvim_cmd, { cmd = "messages" }, { output = true })

	if ok and type(messages) == "string" then
		output = messages
	end

	local entries = {}

	for line in output:gmatch("[^\r\n]+") do
		if line ~= "" and not is_logger_message(line) then
			table.insert(entries, {
				time_label = "startup",
				level = startup_level(line),
				tag = "NVIM",
				message = line,
			})
		end
	end

	return entries
end

local function add_highlight(view, line, group, start_col, end_col)
	table.insert(view.highlights, {
		line = line,
		group = group,
		start_col = start_col,
		end_col = end_col,
	})
end

local function add_line(view, text)
	table.insert(view.lines, text)
	return #view.lines
end

local function ellipsize(value, width)
	value = tostring(value or "")

	if #value <= width then
		return value
	end

	if width <= 1 then
		return string.sub(value, 1, width)
	end

	return string.sub(value, 1, width - 1) .. "..."
end

local function time_label(entry)
	if entry.time_label then
		return entry.time_label
	end

	if not entry.time then
		return "--:--:--"
	end

	return os.date("%H:%M:%S", entry.time) or "--:--:--"
end

local function message_lines(message)
	local lines = {}
	message = tostring(message or "")

	for line in (message .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end

	if #lines == 0 then
		table.insert(lines, "")
	end

	return lines
end

local function strip_logger_prefix(entry, line)
	local prefix = string.format("[%s] %s: ", entry.tag, entry.level:upper())

	if line:sub(1, #prefix) == prefix then
		return line:sub(#prefix + 1)
	end

	return line
end

local function add_entry(view, entry)
	local level = entry.level:upper()
	local tag = ellipsize(entry.tag, TAG_WIDTH)
	local lines = message_lines(entry.message)
	local first_message = strip_logger_prefix(entry, lines[1])

	local line = string.format("%-8s  %-" .. LEVEL_WIDTH .. "s  %-" .. TAG_WIDTH .. "s  %s", time_label(entry), level, tag, first_message)
	local line_nr = add_line(view, line)
	local level_start = 10
	local tag_start = level_start + LEVEL_WIDTH + 2
	local message_start = tag_start + TAG_WIDTH + 2

	add_highlight(view, line_nr, "DebugMuted", 0, 8)
	add_highlight(view, line_nr, level_highlights[entry.level] or "DebugValue", level_start, level_start + #level)
	add_highlight(view, line_nr, "DebugLabel", tag_start, tag_start + #tag)
	add_highlight(view, line_nr, "DebugValue", message_start, -1)

	for i = 2, #lines do
		local continuation = string.rep(" ", message_start) .. lines[i]
		local continuation_nr = add_line(view, continuation)
		add_highlight(view, continuation_nr, "DebugValue", message_start, -1)
	end
end

---@return { lines: string[], highlights: table[] }
function M.render()
	local view = {
		lines = {},
		highlights = {},
	}

	local entries = startup_entries()
	vim.list_extend(entries, Logger.history())

	if #entries == 0 then
		local line_nr = add_line(view, "No debug logs recorded yet.")
		add_highlight(view, line_nr, "DebugMuted", 0, -1)
		return view
	end

	local header = string.format("%-8s  %-" .. LEVEL_WIDTH .. "s  %-" .. TAG_WIDTH .. "s  %s", "Time", "Level", "Tag", "Message")
	local header_nr = add_line(view, header)
	add_highlight(view, header_nr, "DebugHeader", 0, -1)
	local separator_nr = add_line(view, string.rep("-", #header))
	add_highlight(view, separator_nr, "DebugBorder", 0, -1)

	for _, entry in ipairs(entries) do
		add_entry(view, entry)
	end

	return view
end

return M
