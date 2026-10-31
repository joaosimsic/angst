---@type Keybinder
local Keybinder = require("common.Keybinder")

local MAX_LINES = 200
local MAX_CHARS = 8000
local CONTEXT_RADIUS = 15
local RESIZE_STEPS = 3
local FALLBACK_DELAY_MS = 2000
local POLL_MS = 500
local MIN_WAIT_MS = 3000
local READY_TIMEOUT_MS = 60000
local LOG_POLL_MS = 500
local LOG_TIMEOUT_MS = 90000
local CONNECT_GRACE_MS = 1000
local CONNECT_MARKER = 'message="global event connected"'
local TMP_PREFIX = "opencode-ask-"
local TMP_KEEP_S = 7 * 24 * 3600

local function display_path(abs)
	if abs == "" then
		return "[No Name]"
	end
	local rel = vim.fn.fnamemodify(abs, ":~:.")
	if rel ~= "" then
		return rel
	end
	return abs
end

local function absolute_ref(abs, from, to, col)
	if abs == "" then
		abs = "[No Name]"
	end
	if col then
		return string.format("%s:%d:%d", abs, from, col)
	end
	return string.format("%s:%d-%d", abs, from, to)
end

local function truncate_lines(lines, from, to)
	local total = to - from + 1
	if #lines > MAX_LINES then
		local kept = {}
		for i = 1, MAX_LINES do
			kept[i] = lines[i]
		end
		kept[#kept + 1] = string.format("... [truncated %d lines]", total - MAX_LINES)
		lines = kept
	end
	local text = table.concat(lines, "\n")
	if #text > MAX_CHARS then
		text = text:sub(1, MAX_CHARS) .. "\n... [truncated]"
	end
	return text
end

local function buffer_context(buf, from, to)
	local count = vim.api.nvim_buf_line_count(buf)
	from = math.max(1, from)
	to = math.min(count, to)
	if from > to then
		return "", from, to
	end
	local lines = vim.api.nvim_buf_get_lines(buf, from - 1, to, false)
	return truncate_lines(lines, from, to), from, to
end

local function build_file_text(ref, ft, code)
	return string.format("Context: `%s`\n```%s\n%s\n```\n", ref, ft, code)
end

local function sanitize(name)
	return (name:gsub("[^%w%._-]+", "-"):gsub("-+", "-"))
end

local function prune_tmpfiles()
	local ok, names = pcall(vim.fn.glob, "/tmp/" .. TMP_PREFIX .. "*", false, true)
	if not ok or type(names) ~= "table" then
		return
	end
	local now = os.time()
	for _, path in ipairs(names) do
		local mtime = vim.fn.getftime(path)
		if mtime > 0 and now - mtime > TMP_KEEP_S then
			pcall(os.remove, path)
		end
	end
end

local file_seq = 0

local function write_context_file(suffix, text)
	prune_tmpfiles()
	file_seq = file_seq + 1
	local path = string.format("/tmp/%s%d-%d-%s.md", TMP_PREFIX, vim.fn.getpid(), file_seq, sanitize(suffix))
	vim.fn.writefile(vim.split(text, "\n", { plain = true }), path)
	return path
end

local function build_ref_line(path)
	return "@" .. path .. " My question: "
end

local function context_for_visual()
	local buf = vim.api.nvim_get_current_buf()
	local abs = vim.api.nvim_buf_get_name(buf)
	local start_line = vim.fn.getpos("'<")[2]
	local end_line = vim.fn.getpos("'>")[2]
	if start_line < 1 or end_line < 1 then
		return nil
	end
	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end
	local code, from, to = buffer_context(buf, start_line, end_line)
	local rel = display_path(abs)
	local text = build_file_text(absolute_ref(abs, from, to), vim.bo[buf].filetype, code)
	return text, string.format("%s-%d-%d", rel, from, to)
end

local function context_for_normal()
	local buf = vim.api.nvim_get_current_buf()
	local abs = vim.api.nvim_buf_get_name(buf)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1], cursor[2] + 1
	local code = buffer_context(buf, row - CONTEXT_RADIUS, row + CONTEXT_RADIUS)
	local rel = display_path(abs)
	local text = build_file_text(absolute_ref(abs, row, row, col), vim.bo[buf].filetype, code)
	return text, string.format("%s-%d-%d", rel, row, col)
end

local function in_zellij()
	return vim.fn.executable("zellij") == 1 and vim.env.ZELLIJ ~= nil and vim.env.ZELLIJ ~= ""
end

local function shrink_new_pane(pane_id)
	for _ = 1, RESIZE_STEPS do
		if pane_id ~= nil and pane_id ~= "" then
			pcall(vim.system, { "zellij", "action", "resize", "-p", pane_id, "decrease", "left" })
		else
			pcall(vim.system, { "zellij", "action", "resize", "decrease", "left" })
		end
	end
end

local function dump_screen(pane_id)
	local result = vim.system({ "zellij", "action", "dump-screen", "-p", pane_id }, { text = true }):wait()
	if result.code ~= 0 then
		return nil
	end
	return result.stdout or ""
end

local function write_ref_line(pane_id, line)
	local ok, obj = pcall(vim.system, { "zellij", "action", "write-chars", "-p", pane_id, line }, { text = true })
	if not ok or obj == nil then
		vim.notify("opencode-ask: zellij write-chars failed to start", vim.log.levels.ERROR)
		return
	end
	local result = obj:wait()
	if result.code ~= 0 then
		vim.notify("opencode-ask: zellij write-chars failed", vim.log.levels.ERROR)
	end
end

local function opencode_log_path()
	local data = vim.env.XDG_DATA_HOME
	if data == nil or data == "" then
		data = vim.fn.expand("~/.local/share")
	end
	local dir = data .. "/opencode/log"
	local main = dir .. "/opencode.log"
	if vim.fn.filereadable(main) == 1 then
		return main
	end
	local ok, names = pcall(vim.fn.glob, dir .. "/*.log", false, true)
	if ok and type(names) == "table" and #names > 0 then
		table.sort(names, function(a, b)
			return vim.fn.getftime(a) > vim.fn.getftime(b)
		end)
		return names[1]
	end
	return nil
end

local function file_size(path)
	local ok, size = pcall(vim.fn.getfsize, path)
	if not ok or size < 0 then
		return nil
	end
	return size
end

local function read_appended(path, offset)
	local f = io.open(path, "r")
	if f == nil then
		return nil, offset
	end
	local size = f:seek("end")
	if size == nil or size < offset then
		f:close()
		return "", 0
	end
	f:seek("set", offset)
	local chunk = f:read("*a") or ""
	f:close()
	return chunk, size
end

local function watch_log_for_connect(log_path, is_done, on_event)
	local offset = file_size(log_path) or 0
	local attempts = 0
	local max_attempts = math.floor(LOG_TIMEOUT_MS / LOG_POLL_MS)
	local function tick()
		if is_done() then
			return
		end
		attempts = attempts + 1
		local chunk, pos = read_appended(log_path, offset)
		if chunk ~= nil then
			offset = pos
			if chunk:find(CONNECT_MARKER, 1, true) then
				vim.defer_fn(on_event, CONNECT_GRACE_MS)
				return
			end
		end
		if attempts >= max_attempts then
			if not is_done() then
				vim.notify("opencode-ask: no connect event, prefilling anyway", vim.log.levels.WARN)
				on_event()
			end
			return
		end
		vim.defer_fn(tick, LOG_POLL_MS)
	end
	tick()
end

local function poll_and_prefill(pane_id, line)
	local sent = false
	local function prefill()
		if sent then
			return
		end
		sent = true
		write_ref_line(pane_id, line)
	end
	local function is_done()
		return sent
	end
	local start = vim.uv.now()
	local last = nil
	local nils = 0
	local max_attempts = math.floor(READY_TIMEOUT_MS / POLL_MS)
	local attempts = 0
	local function tick()
		if sent then
			return
		end
		attempts = attempts + 1
		local screen = dump_screen(pane_id)
		if screen == nil then
			nils = nils + 1
			if nils >= 5 then
				vim.notify("opencode-ask: pane gone, context not prefilled", vim.log.levels.ERROR)
				return
			end
		else
			nils = 0
			local elapsed = vim.uv.now() - start
			if screen ~= "" and screen == last and elapsed >= MIN_WAIT_MS then
				prefill()
				return
			end
			last = screen
		end
		if attempts >= max_attempts then
			if not sent then
				vim.notify("opencode-ask: TUI not settled, prefilling anyway", vim.log.levels.WARN)
				prefill()
			end
			return
		end
		vim.defer_fn(tick, POLL_MS)
	end
	tick()
	local log_path = opencode_log_path()
	if log_path ~= nil then
		watch_log_for_connect(log_path, is_done, prefill)
	end
end

local function open_in_zellij(text, suffix)
	local cwd = vim.fn.getcwd()
	local result = vim.system({
		"zellij",
		"action",
		"new-pane",
		"--direction",
		"right",
		"--cwd",
		cwd,
		"--name",
		"opencode-ask",
		"--",
		"opencode",
	}, { text = true }):wait()
	if result.code ~= 0 then
		vim.notify("opencode-ask: zellij new-pane failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
		return
	end
	local pane_id = (result.stdout or ""):gsub("%s+", "")
	shrink_new_pane(pane_id)
	if pane_id == "" then
		vim.notify("opencode-ask: no pane id, context not prefilled", vim.log.levels.WARN)
		return
	end
	local path = write_context_file(suffix, text)
	poll_and_prefill(pane_id, build_ref_line(path))
end

local function open_fallback(text, suffix)
	local path = write_context_file(suffix, text)
	local line = build_ref_line(path)
	vim.cmd("vsplit")
	local chan = vim.fn.jobstart({ "opencode" }, { term = true })
	vim.cmd("startinsert")
	if chan <= 0 then
		vim.notify("opencode-ask: failed to start opencode", vim.log.levels.ERROR)
		return
	end
	local sent = false
	local function send()
		if sent then
			return
		end
		sent = true
		pcall(vim.api.nvim_chan_send, chan, line)
	end
	local function is_done()
		return sent
	end
	local log_path = opencode_log_path()
	if log_path == nil then
		vim.defer_fn(send, FALLBACK_DELAY_MS)
		return
	end
	watch_log_for_connect(log_path, is_done, send)
end

local function ask_visual()
	local text, suffix = context_for_visual()
	if not text then
		vim.notify("opencode-ask: no visual selection", vim.log.levels.WARN)
		return
	end
	if in_zellij() then
		open_in_zellij(text, suffix)
	else
		open_fallback(text, suffix)
	end
end

local function ask_normal()
	local text, suffix = context_for_normal()
	if in_zellij() then
		open_in_zellij(text, suffix)
	else
		open_fallback(text, suffix)
	end
end

---@type Plugin
return {
	"opencode-ask",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local binder = Keybinder.new(nil, "OPENCODE")
		binder:nmap("<leader>oa", ask_normal, { desc = "Ask opencode in zellij pane" })
		binder:vmap("<leader>oa", ask_visual, { desc = "Ask opencode about selection" })
	end,
}
