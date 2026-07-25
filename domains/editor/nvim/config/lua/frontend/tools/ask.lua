local Keybinder = require("common.Keybinder")
local Logger = require("common.Logger")

local log = Logger.new("ask", "debug")

local M = {}

local ns_id = vim.api.nvim_create_namespace("ask")
local config = {
	base_url = "https://opencode.ai/zen/go/v1",
	model = "deepseek-v4-flash",
	max_tokens = 2048,
}

local function show_response(bufnr, extmark_id, extmark_line, answer)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local ok = pcall(vim.api.nvim_buf_get_extmark_by_id, bufnr, ns_id, extmark_id, {})
	if not ok then
		return
	end

	local lines = vim.split(answer, "\n")
	local virt_lines = {}
	local max_width = math.max(20, vim.fn.winwidth(0) - 2)
	for _, line in ipairs(lines) do
		local trimmed = vim.trim(line)
		while #trimmed > max_width do
			table.insert(virt_lines, { { "  " .. trimmed:sub(1, max_width), "Comment" } })
			trimmed = trimmed:sub(max_width + 1)
		end
		if #trimmed > 0 then
			table.insert(virt_lines, { { "  " .. trimmed, "Comment" } })
		end
	end
	table.insert(virt_lines, { { "  [q]", "NonText" } })

	vim.api.nvim_buf_set_extmark(bufnr, ns_id, extmark_line, 0, {
		id = extmark_id,
		virt_lines = virt_lines,
	})
end

local function distribute_response(bufnr, extmark_id, start_0idx, end_0idx, answer)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)

	local lines = vim.split(answer, "\n")
	local max_width = math.max(20, vim.fn.winwidth(0) - 2)

	local function wrap_and_add(list, text)
		local trimmed = vim.trim(text)
		if trimmed == "" then
			return
		end
		while #trimmed > max_width do
			table.insert(list, trimmed:sub(1, max_width))
			trimmed = trimmed:sub(max_width + 1)
		end
		if #trimmed > 0 then
			table.insert(list, trimmed)
		end
	end

	local line_entries = {}
	local seq_lines = {}
	local has_refs = false
	local current_ref = nil

	for _, line in ipairs(lines) do
		local ref, rest = line:match("^L(%d+):%s*(.*)$")
		if ref then
			current_ref = tonumber(ref) - 1
			has_refs = true
			if not line_entries[current_ref] then
				line_entries[current_ref] = {}
			end
			wrap_and_add(line_entries[current_ref], rest)
		elseif has_refs then
			if current_ref then
				wrap_and_add(line_entries[current_ref], line)
			end
		else
			wrap_and_add(seq_lines, line)
		end
	end

	if has_refs then
		local chunks = {}
		for linenr, entry in pairs(line_entries) do
			if linenr >= start_0idx and linenr <= end_0idx and #entry > 0 then
				local chunk = {}
				for _, item in ipairs(entry) do
					table.insert(chunk, { { "  " .. item, "Comment" } })
				end
				chunks[linenr] = chunk
			end
		end

		local max_linenr = -1
		for linenr, _ in pairs(chunks) do
			if linenr > max_linenr then
				max_linenr = linenr
			end
		end
		if chunks[max_linenr] then
			table.insert(chunks[max_linenr], { { "  [q]", "NonText" } })
		end

		for linenr, chunk in pairs(chunks) do
			if #chunk > 0 then
				vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr, 0, {
					virt_lines = chunk,
				})
			end
		end
		return
	end

	if #seq_lines == 0 then
		return
	end

	local num_source_lines = end_0idx - start_0idx + 1
	local lines_per_source = math.max(1, math.ceil(#seq_lines / num_source_lines))

	local chunks = {}
	local idx = 1
	for linenr = start_0idx, end_0idx do
		local chunk = {}
		for _ = 1, lines_per_source do
			if idx > #seq_lines then
				break
			end
			table.insert(chunk, { { "  " .. seq_lines[idx], "Comment" } })
			idx = idx + 1
		end
		chunks[linenr] = chunk
	end

	for linenr = end_0idx, start_0idx, -1 do
		if chunks[linenr] and #chunks[linenr] > 0 then
			table.insert(chunks[linenr], { { "  [q]", "NonText" } })
			break
		end
	end

	for linenr, chunk in pairs(chunks) do
		if #chunk > 0 then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr, 0, {
				virt_lines = chunk,
			})
		end
	end
end

function M.ask(opts)
	local curl = require("plenary.curl")

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

	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

	local _, prompt_extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, extmark_line, 0, {
		virt_lines = {
			{ { "Prompt: ", "Comment" } },
		},
	})

	local input_line = extmark_line + 1
	vim.api.nvim_buf_set_lines(bufnr, input_line, input_line, false, { "" })
	vim.api.nvim_win_set_cursor(0, { input_line + 1, 0 })

	local function cleanup()
		pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, prompt_extmark_id)
		pcall(vim.api.nvim_buf_set_lines, bufnr, input_line, input_line + 1, false, {})
		pcall(vim.api.nvim_buf_del_keymap, bufnr, 'i', '<CR>')
		pcall(vim.api.nvim_buf_del_keymap, bufnr, 'i', '<Esc>')
	end

	local function submit()
		vim.cmd("stopinsert")
		local lines = vim.api.nvim_buf_get_lines(bufnr, input_line, input_line + 1, false)
		local input = vim.trim(lines[1] or "")
		cleanup()

		if input == "" then
			return
		end

		local frames = {
			"  Thinking   ",
			"  Thinking.  ",
			"  Thinking.. ",
			"  Thinking...",
		}
		local frame_idx = 0

		local _, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, extmark_line, 0, {
			virt_lines = {
				{ { frames[1], "Comment" } },
			},
		})
		if not extmark_id then
			return
		end

		local timer = assert(vim.loop.new_timer())
		timer:start(0, 350, vim.schedule_wrap(function()
			frame_idx = (frame_idx + 1) % #frames
			pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, extmark_line, 0, {
				id = extmark_id,
				virt_lines = { { { frames[frame_idx + 1], "Comment" } } },
			})
		end))

		local function stop_animating()
			pcall(timer.close, timer)
		end

		local handle_response = vim.schedule_wrap(function(response)
			stop_animating()

			if not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end

			log:info(function()
				return string.format("response received: exit=%d headers=%s body=%s",
					response.exit, vim.inspect(response.headers), tostring(response.body))
			end)

			if response.exit ~= 0 then
				log:error("curl exit=" .. response.exit .. " body=" .. tostring(response.body))
				show_response(bufnr, extmark_id, extmark_line, "curl error (exit " .. response.exit .. ")")
				return
			end

			local ok, res = pcall(vim.fn.json_decode, response.body)
			if not ok then
				log:error("json decode failed body=" .. tostring(response.body))
				show_response(bufnr, extmark_id, extmark_line, "Failed to parse API response")
				return
			end

			log:info(function()
				return string.format("parsed response: %s", vim.inspect(res))
			end)

			if res.error then
				local msg = type(res.error) == "table" and (res.error.message or vim.inspect(res.error))
					or tostring(res.error)
				log:error("api error=" .. msg)
				show_response(bufnr, extmark_id, extmark_line, msg)
				return
			end

			local answer = res.choices and res.choices[1] and res.choices[1].message and res.choices[1].message.content
			if answer == nil or vim.trim(answer) == "" then
				log:warn(function()
					return string.format("content empty: exit=%d answer=%s parsed=%s",
						response.exit, vim.inspect(answer), vim.inspect(res))
				end)
				show_response(bufnr, extmark_id, extmark_line, "Empty response from API")
				return
			end

			log:info(function()
				return string.format("distributing answer (%d lines): %s",
					#vim.split(answer, "\n"), vim.trim(answer))
			end)

			distribute_response(bufnr, extmark_id, start_line_1idx - 1, extmark_line, vim.trim(answer))
		end)

		local system_prompt = "You are a concise coding assistant. Code lines are prefixed with their line number (L<number>:). "
			.. "Explain each line by referencing its number. Return one line per code line, "
			.. "formatted as L<line_number>: <explanation>. Keep each explanation under 80 characters. No preamble."
		local user_prompt = string.format("Code:\n```\n%s\n```\n\nQuestion: %s", numbered_code, input)

		local api_key = config.api_key or vim.env.OPENAI_API_KEY
		if not api_key then
			stop_animating()
			show_response(bufnr, extmark_id, extmark_line, "Set OPENAI_API_KEY or configure api_key")
			return
		end

		log:info(function()
				local safe_body = vim.fn.json_encode({
					model = config.model,
					messages = {
						{ role = "system", content = system_prompt },
						{ role = "user", content = user_prompt },
					},
					max_tokens = config.max_tokens,
				})
				return string.format("sending request: url=%s body=%s",
					config.base_url .. "/chat/completions", safe_body)
			end)

		curl.request({
			url = config.base_url .. "/chat/completions",
			method = "POST",
			headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. api_key,
			},
			body = vim.fn.json_encode({
				model = config.model,
				messages = {
					{ role = "system", content = system_prompt },
					{ role = "user", content = user_prompt },
				},
				max_tokens = config.max_tokens,
			}),
			timeout = 30000,
			callback = handle_response,
		})
	end

	local function cancel()
		vim.cmd("stopinsert")
		cleanup()
	end

	vim.keymap.set('i', '<CR>', submit, { buffer = bufnr, noremap = true, silent = true })
	vim.keymap.set('i', '<Esc>', cancel, { buffer = bufnr, noremap = true, silent = true })

	vim.cmd("startinsert")
end

function M.dismiss()
	vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
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
