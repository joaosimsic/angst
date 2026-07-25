local Logger = require("common.Logger")
local display = require("frontend.tools.ask.display")

local log = Logger.new("ask.api", "debug")

local config = {
	base_url = "https://opencode.ai/zen/go/v1",
	model = "deepseek-v4-flash",
	max_tokens = 8192,
}

local function get_frames(indent)
	return {
		indent .. "Thinking   ",
		indent .. "Thinking.  ",
		indent .. "Thinking.. ",
		indent .. "Thinking...",
	}
end

local function process_sse(buffer, content)
	local complete = false
	while true do
		local dbl = buffer:find("\n\n")
		if not dbl then
			break
		end

		local event = buffer:sub(1, dbl - 1)
		buffer = buffer:sub(dbl + 2)

		for line in event:gmatch("[^\r\n]+") do
			local payload = line:match("^data: (.*)$")
			if payload then
				if payload == "[DONE]" then
					complete = true
				else
					local ok, json = pcall(vim.fn.json_decode, payload)
					if ok and json.choices and json.choices[1] then
						local delta = json.choices[1].delta or {}
						local chunk = delta.content
						if type(chunk) == "string" then
							content = content .. chunk
						end
					end
				end
			end
		end
	end
	return buffer, content, complete
end

local M = {}

function M.submit(opts)
	local curl = require("plenary.curl")

	local bufnr = opts.bufnr
	local extmark_line = opts.extmark_line
	local start_line_1idx = opts.start_line_1idx
	local end_line_1idx = opts.end_line_1idx
	local numbered_code = opts.numbered_code
	local input = opts.input

	local frames = get_frames(display.get_indent(bufnr, extmark_line))
	local frame_idx = 0

	local _, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
		virt_lines = {
			{ { frames[1], "Comment" } },
		},
	})
	if not extmark_id then
		return
	end

	local timer = assert(vim.loop.new_timer())
	timer:start(0, 350, vim.schedule_wrap(function()
		if received_first_content then return end
		frame_idx = (frame_idx + 1) % #frames
		pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
			id = extmark_id,
			virt_lines = { { { frames[frame_idx + 1], "Comment" } } },
		})
	end))

	local function stop_animating()
		pcall(timer.close, timer)
	end

	local sse_buffer = ""
	local accumulated_content = ""
	local stream_complete = false
	local received_first_content = false

	local function update_display()
		if stream_complete then
			stop_animating()
		elseif not received_first_content and #accumulated_content > 0 then
			received_first_content = true
			stop_animating()
		end

		if #accumulated_content > 0 then
			display.stream_update(bufnr, extmark_id, extmark_line, accumulated_content)
		end
	end

	local stream_handler = vim.schedule_wrap(function(err, data)
		if err or stream_complete or not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		if data == nil then
			return
		end

		sse_buffer = sse_buffer .. data .. "\n"
		sse_buffer, accumulated_content, stream_complete = process_sse(sse_buffer, accumulated_content)
		update_display()
	end)

	local callback = vim.schedule_wrap(function(response)
		stop_animating()

		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		log:info(function()
			return string.format("response: exit=%d status=%s", response.exit, tostring(response.status))
		end)

		if response.exit ~= 0 then
			log:error("curl exit=" .. response.exit)
			display.show_response(bufnr, extmark_id, extmark_line, "curl error (exit " .. response.exit .. ")")
			return
		end

		if response.status and response.status >= 400 then
			local body = tostring(response.body)
			local ok, res = pcall(vim.fn.json_decode, body)
			local msg = "HTTP " .. response.status
			if ok and res and res.error then
				msg = msg .. ": " .. (type(res.error) == "table" and (res.error.message or vim.inspect(res.error)) or tostring(res.error))
			end
			log:error("api error=" .. msg)
			display.show_response(bufnr, extmark_id, extmark_line, msg)
			return
		end

		if stream_complete or #accumulated_content > 0 then
			local answer = vim.trim(accumulated_content)
			if answer == "" then
				display.show_response(bufnr, extmark_id, extmark_line, "Empty response from API")
				return
			end
			log:info(function()
				return string.format("distributing answer (%d lines)",
					#vim.split(answer, "\n"))
			end)
			display.distribute_response(bufnr, extmark_id, start_line_1idx - 1, extmark_line, answer)
			return
		end

		display.show_response(bufnr, extmark_id, extmark_line, "Empty response from API")
	end)

	local system_prompt = "You are a concise coding assistant. Code lines are prefixed with their line number (L<number>:). "
		.. "Explain each line by referencing its number. Return one line per code line, "
		.. "formatted as L<line_number>: <explanation>. "
		.. "Skip trivial lines like empty lines, braces, and syntax-only lines unless the question asks about them. No preamble."
	local user_prompt = string.format("Code:\n```\n%s\n```\n\nQuestion: %s", numbered_code, input)

	local api_key = config.api_key or vim.env.OPENAI_API_KEY
	if not api_key then
		stop_animating()
		display.show_response(bufnr, extmark_id, extmark_line, "Set OPENAI_API_KEY or configure api_key")
		return
	end

	local request_body = vim.fn.json_encode({
		model = config.model,
		messages = {
			{ role = "system", content = system_prompt },
			{ role = "user", content = user_prompt },
		},
		max_tokens = config.max_tokens,
		stream = true,
	})

	log:info(function()
		return string.format("sending request: url=%s body=%s",
			config.base_url .. "/chat/completions", request_body)
	end)

	curl.request({
		url = config.base_url .. "/chat/completions",
		method = "POST",
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. api_key,
		},
		body = request_body,
		timeout = 30000,
		stream = stream_handler,
		callback = callback,
	})
end

return M
