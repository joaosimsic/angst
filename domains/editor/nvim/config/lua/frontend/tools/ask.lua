local Keybinder = require("common.Keybinder")

local M = {}

local ns_id = vim.api.nvim_create_namespace("ask")
local config = {
	base_url = "https://opencode.ai/zen/go/v1",
	model = "deepseek-v4-flash",
}

local send_request
local show_response

function M.setup(user_opts)
	config = vim.tbl_deep_extend("force", config, user_opts or {})
end

function M.ask()
	local bufnr = vim.api.nvim_get_current_buf()

	local mode = vim.api.nvim_get_mode().mode
	local start_line_1idx, end_line_1idx
	local code

	if mode == "v" or mode == "V" or mode == "" then
		local reg_save = vim.fn.getreg('"')
		local regtype_save = vim.fn.getregtype('"')
		vim.cmd('normal! "vy')
		code = vim.fn.getreg('"')
		vim.fn.setreg('"', reg_save, regtype_save)
		local s_start = vim.fn.getpos("'<")
		local s_end = vim.fn.getpos("'>")
		start_line_1idx = s_start[2]
		end_line_1idx = s_end[2]
	else
		local cursor = vim.api.nvim_win_get_cursor(0)
		start_line_1idx = cursor[1]
		end_line_1idx = cursor[1]
		local lines = vim.api.nvim_buf_get_lines(bufnr, start_line_1idx - 1, start_line_1idx, false)
		code = lines[1] or ""
	end

	local extmark_line = end_line_1idx - 1

	vim.ui.input({ prompt = "Ask: " }, function(input)
		if not input or input == "" then
			return
		end

		local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, extmark_line, 0, {
			virt_lines = {
				{ { "  ...", "Comment" } },
			},
		})

		local system_prompt = "You are a concise coding assistant. Answer in at most 5 lines. No preamble."
		local user_prompt = string.format("Code:\n```\n%s\n```\n\nQuestion: %s", code, input)

		send_request(system_prompt, user_prompt, function(answer)
			show_response(bufnr, extmark_id, extmark_line, answer)
		end)
	end)
end

function M.dismiss()
	vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
end

function send_request(system_prompt, user_prompt, callback)
	local api_key = config.api_key or vim.env.OPENAI_API_KEY
	if not api_key then
		callback("Set OPENAI_API_KEY or configure api_key")
		return
	end

	local body = vim.fn.json_encode({
		model = config.model,
		messages = {
			{ role = "system", content = system_prompt },
			{ role = "user", content = user_prompt },
		},
		max_tokens = 300,
	})

	vim.system({
		"curl",
		"-s",
		"-X",
		"POST",
		config.base_url .. "/chat/completions",
		"-H",
		"Content-Type: application/json",
		"-H",
		"Authorization: Bearer " .. api_key,
		"--data-binary",
		"@-",
	}, { stdin = body, text = true, timeout = 30000 }, function(result)
		if result.code ~= 0 then
			callback("curl error (exit " .. result.code .. ")")
			return
		end
		local ok, res = pcall(vim.fn.json_decode, result.stdout)
		if not ok then
			callback("Failed to parse API response")
			return
		end
		if res.error then
			local msg = type(res.error) == "table" and (res.error.message or vim.inspect(res.error))
				or tostring(res.error)
			callback(msg)
			return
		end
		local answer = res.choices and res.choices[1] and res.choices[1].message and res.choices[1].message.content
		if not answer then
			callback("Unexpected API response format")
			return
		end
		callback(vim.trim(answer))
	end)
end

function show_response(bufnr, extmark_id, extmark_line, answer)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local ok = pcall(vim.api.nvim_buf_get_extmark_by_id, bufnr, ns_id, extmark_id, {})
	if not ok then
		return
	end

	local lines = vim.split(answer, "\n")
	local virt_lines = {}
	for _, line in ipairs(lines) do
		table.insert(virt_lines, { { "  " .. vim.trim(line), "Comment" } })
	end
	table.insert(virt_lines, { { "  [q]", "NonText" } })

	vim.api.nvim_buf_set_extmark(bufnr, ns_id, extmark_line, 0, {
		id = extmark_id,
		virt_lines = virt_lines,
	})
end

return {
	"ask",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local binder = Keybinder.new(nil, "ASK")
		binder:set_debug(true)
		binder:nmap("<leader>?", M.ask, { desc = "Ask about code" })
		binder:nmap("<leader>q", M.dismiss, { desc = "Dismiss ask response" })
	end,
}
