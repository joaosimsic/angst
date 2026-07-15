local ns = vim.api.nvim_create_namespace("terminal_output")

local function extmark(buf, row, start_col, end_col, hl_group)
	vim.api.nvim_buf_set_extmark(buf, ns, row, start_col, { hl_group = hl_group, end_col = end_col })
end

local M = {}

---@param buf integer
function M.apply(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	for i, line in ipairs(lines) do
		local row = i - 1
		local len = #line
		if len == 0 then
			goto continue
		end

		if
			line:find("^[a-z_]+: command not found")
			or line:find("^zsh:")
			or line:find("^bash:")
			or line:find("^nu:")
		then
			extmark(buf, row, 0, len, "TermError")
			goto continue
		end

		if line:find("^%^[CDZ\\]") then
			extmark(buf, row, 0, len, "TermSignal")
			goto continue
		end

		if line:match("^[%a_][%w_]*") and (line:find("~/") or line:find(" %[")) then
			local user_end = line:find("%s")
			if user_end then
				extmark(buf, row, 0, user_end - 1, "TermUser")
			end

			local last_end = 0

			local function add_hl(pattern, group)
				local s, e = line:find(pattern)
				if s then
					extmark(buf, row, s - 1, e, group)
					return e
				end
			end

			local pe

			pe = add_hl("~[%w%._%-/]*", "TermPath")
			if pe then
				last_end = math.max(last_end, pe)
			end

			pe = add_hl("%*[%w%._%-/]+", "TermGitBranch")
			if pe then
				last_end = math.max(last_end, pe)
			end

			pe = add_hl("%[[%+%-%?!%%%~%*rx]+%]", "TermGitStatus")
			if pe then
				last_end = math.max(last_end, pe)
			end

			if last_end > 0 and last_end < len then
				extmark(buf, row, last_end, len, "TermCommand")
			end

			goto continue
		end

		::continue::
	end
end

return M
