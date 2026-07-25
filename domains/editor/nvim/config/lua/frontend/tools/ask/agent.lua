local Logger = require("common.Logger")
local display = require("frontend.tools.ask.display")
local api = require("frontend.tools.ask.api")
local tools = require("frontend.tools.ask.tools")

local log = Logger.new("ask.agent", "debug")

local MAX_DEPTH = 8

local M = {}

local function build_messages(numbered_code, input)
	local system = "You are a concise coding assistant with access to the codebase. "
		.. "You can use tools to search code and read files. "
		.. "Use tools to gather relevant context before answering code questions.\n\n"
		.. "Available tools:\n"
		.. "- search_code(query, max_results?, include?): Search the codebase using ripgrep. Returns file:line:content.\n"
		.. "- read_file_lines(path, start_line?, end_line?): Read specific lines from a file.\n\n"
		.. "When the user asks about code, search for relevant symbols, imports, definitions, and usages. "
		.. "Code lines are prefixed with their line number (L<number>:). "
		.. "Explain each line by referencing its number. Return one line per code line, "
		.. "formatted as L<line_number>: <explanation>. "
		.. "Skip trivial lines like empty lines, braces, and syntax-only lines unless the question asks about them. No preamble."

	local user = string.format("Code:\n```\n%s\n```\n\nQuestion: %s", numbered_code, input)

	return {
		{ role = "system", content = system },
		{ role = "user", content = user },
	}
end

local function refresh_display(state)
	if not vim.api.nvim_buf_is_valid(state.bufnr) then return end
	display.show_tool_actions(state.bufnr, state.extmark_id, state.extmark_line, state.actions)
end

local function add_action(text, state)
	table.insert(state.actions, "  " .. text)
	refresh_display(state)
end

local function show_error(msg, state)
	if not vim.api.nvim_buf_is_valid(state.bufnr) then return end
	display.show_response(state.bufnr, state.extmark_id, state.extmark_line, msg)
end

local function show_final(content, state)
	if not vim.api.nvim_buf_is_valid(state.bufnr) then return end
	local trimmed = vim.trim(content or "")
	if trimmed == "" then
		display.show_response(state.bufnr, state.extmark_id, state.extmark_line, "Empty response from API")
		return
	end
	display.distribute_response(state.bufnr, state.extmark_id, state.start_0idx, state.extmark_line, trimmed)
end

local function tool_preview(tc)
	local ok, args = pcall(vim.fn.json_decode, tc["function"].arguments)
	if not ok then args = {} end

	if tc["function"].name == "search_code" then
		return tc["function"].name .. '("' .. (args.query or "?") .. '")'
	elseif tc["function"].name == "read_file_lines" then
		local preview = tc["function"].name .. "(" .. (args.path or "?")
		if args.start_line then
			preview = preview .. ":" .. args.start_line
		end
		return preview .. ")"
	end
	return tc["function"].name .. "(...)"
end

local function handle_tool_calls(tool_calls, messages, state)
	table.insert(messages, {
		role = "assistant",
		content = "",
		tool_calls = tool_calls,
	})

	for _, tc in ipairs(tool_calls) do
		add_action(tool_preview(tc), state)

		local ok, args = pcall(vim.fn.json_decode, tc["function"].arguments)
		if not ok then args = {} end

		local result = tools.execute(tc["function"].name, args, state.project_root)

		log:info(function()
			return string.format("tool %s: %d chars", tc["function"].name, #result)
		end)

		table.insert(messages, {
			role = "tool",
			tool_call_id = tc.id,
			content = result,
		})
	end
end

local function agent_round(messages, state, depth)
	if not vim.api.nvim_buf_is_valid(state.bufnr) then return end
	if depth > MAX_DEPTH then
		show_error("Reached maximum tool call depth", state)
		return
	end

	log:info(function()
		return string.format("agent round %d: %d messages", depth + 1, #messages)
	end)

	api.chat(messages, tools.definitions, state.api_key,
		function(message)
			if message.tool_calls and #message.tool_calls > 0 then
				handle_tool_calls(message.tool_calls, messages, state)
				agent_round(messages, state, depth + 1)
				return
			end

			api.chat_stream(messages, state.api_key,
				function(_, accumulated)
					if vim.api.nvim_buf_is_valid(state.bufnr) then
						display.show_incomplete_line(state.bufnr, state.extmark_id, state.extmark_line, accumulated)
					end
				end,
				function(full_content)
					show_final(full_content, state)
				end,
				function(err)
					show_error(err, state)
				end
			)
		end,
		function(err)
			show_error(err, state)
		end
	)
end

function M.run(opts)
	local bufnr = opts.bufnr
	local extmark_line = opts.extmark_line
	local start_line_1idx = opts.start_line_1idx
	local end_line_1idx = opts.end_line_1idx
	local numbered_code = opts.numbered_code
	local input = opts.input
	local project_root = tools.find_project_root(bufnr)
	local api_key = opts.api_key or vim.env.OPENAI_API_KEY

	if not api_key then
		vim.notify("Ask: Set OPENAI_API_KEY", vim.log.levels.ERROR)
		return
	end

	local _, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
		virt_lines = { { { display.get_indent(bufnr, extmark_line) .. "Thinking", "Comment" } } },
	})
	if not extmark_id then return end

	local state = {
		bufnr = bufnr,
		extmark_id = extmark_id,
		extmark_line = extmark_line,
		start_0idx = start_line_1idx - 1,
		api_key = api_key,
		project_root = project_root,
		actions = {},
	}

	local messages = build_messages(numbered_code, input)
	agent_round(messages, state, 0)
end

return M
