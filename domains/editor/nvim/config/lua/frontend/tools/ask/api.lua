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
		frame_idx = (frame_idx + 1) % #frames
		pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
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
			display.show_response(bufnr, extmark_id, extmark_line, "curl error (exit " .. response.exit .. ")")
			return
		end

		local ok, res = pcall(vim.fn.json_decode, response.body)
		if not ok then
			log:error("json decode failed body=" .. tostring(response.body))
			display.show_response(bufnr, extmark_id, extmark_line, "Failed to parse API response")
			return
		end

		log:info(function()
			return string.format("parsed response: %s", vim.inspect(res))
		end)

		if res.error then
			local msg = type(res.error) == "table" and (res.error.message or vim.inspect(res.error))
				or tostring(res.error)
			log:error("api error=" .. msg)
			display.show_response(bufnr, extmark_id, extmark_line, msg)
			return
		end

		local answer = res.choices and res.choices[1] and res.choices[1].message and res.choices[1].message.content
		if answer == nil or vim.trim(answer) == "" then
			log:warn(function()
				return string.format("content empty: exit=%d answer=%s parsed=%s",
					response.exit, vim.inspect(answer), vim.inspect(res))
			end)
			display.show_response(bufnr, extmark_id, extmark_line, "Empty response from API")
			return
		end

		log:info(function()
			return string.format("distributing answer (%d lines): %s",
				#vim.split(answer, "\n"), vim.trim(answer))
		end)

		display.distribute_response(bufnr, extmark_id, start_line_1idx - 1, extmark_line, vim.trim(answer))
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

return M
