local ns = vim.api.nvim_create_namespace("terminal_output")

local function extmark(buf, row, start_col, end_col, hl_group)
	vim.api.nvim_buf_set_extmark(buf, ns, row, start_col, { hl_group = hl_group, end_col = end_col })
end

local function has_high_byte(s)
	return #s > 0 and s:byte(1) > 127
end

local function each_token(line, pos)
	return function()
		local ws = line:find("%S", pos)
		if not ws then return nil end
		local tok_end = line:find("%s", ws)
		if not tok_end then tok_end = #line + 1 end
		pos = tok_end
		return ws, tok_end
	end
end

local M = {}

function M.apply(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	for i, line in ipairs(lines) do
		local row = i - 1
		local len = #line
		if len == 0 then goto continue end

		if line:find("^[a-z_]+: command not found")
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

		if line:find("^:::") then
			extmark(buf, row, 0, len, "TermSignal")
			goto continue
		end

		if line:match("^[%a_][%w_]*") and (line:find("~/") or line:find(" %[")) then
			local user_end = line:find("%s")
			if user_end then
				local user_part = line:sub(1, user_end - 1)
				local at = user_part:find("@")
				if at then
					extmark(buf, row, 0, at - 1, "TermUser")
					extmark(buf, row, at - 1, user_end - 1, "TermUser")
				else
					extmark(buf, row, 0, user_end - 1, "TermUser")
				end
			end

			local function add_hl(pattern, group)
				local s, e = line:find(pattern)
				if s then
					extmark(buf, row, s - 1, e, group)
					return e
				end
			end

			local last_end = 0

			local scan_pos = (user_end or 1) + 1
			local path_pos = line:find("~/", scan_pos)
			local zone_end = path_pos or len
			while scan_pos <= zone_end do
				local s = line:find("%S", scan_pos)
				if not s or s > zone_end then break end
				local e = line:find("%s", s)
				if not e or e > zone_end then e = zone_end + 1 end
				local token = line:sub(s, e - 1)
				if has_high_byte(token) then
					extmark(buf, row, s - 1, e - 1, "TermNixShell")
					last_end = math.max(last_end, e - 1)
				end
				scan_pos = e + 1
			end

			local pe

			pe = add_hl("~[%w%._%-/]*", "TermPath")
			if pe then last_end = math.max(last_end, pe) end

			pe = add_hl("%*[%w%._%-/]+", "TermGitBranch")
			if pe then last_end = math.max(last_end, pe) end

			pe = add_hl("%[[%+%-%?!%%~\226\135\161\226\135\163%*rx0-9]+%]", "TermGitStatus")
			if pe then last_end = math.max(last_end, pe) end

			if last_end > 0 and last_end < len then
				local iter = each_token(line, last_end + 1)
				local in_module = false
				while true do
					local ws, tok_end = iter()
					if not ws then break end
					local token = line:sub(ws, tok_end - 1)

					if in_module then
						if token:match("^%(v?[%d%.]+%)$") then
							extmark(buf, row, ws - 1, tok_end - 1, "TermLangModule")
							in_module = false
							goto token_done
						end
						in_module = false
					end

					if has_high_byte(token) then
						extmark(buf, row, ws - 1, tok_end - 1, "TermLangModule")
						in_module = true
					elseif token == ">" then
						extmark(buf, row, ws - 1, tok_end - 1, "TermSignal")
					else
						extmark(buf, row, ws - 1, len, "TermCommand")
						break
					end

					::token_done::
				end
			end

			goto continue
		end

		::continue::
	end
end

return M
