---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"surround",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local binder = Keybinder.new(nil, "Sandwich")

		local function get_char()
			local ok, char_code = pcall(vim.fn.getchar)
			if not ok then
				return nil
			end

			if type(char_code) == "string" then
				if char_code == "\27" then
					return nil
				end
				return char_code
			end

			if char_code == 27 then
				return nil
			end

			return vim.fn.nr2char(char_code)
		end

		local function get_pairs(char)
			local open, close = char, char
			if char == "{" or char == "}" then
				open, close = "{ ", " }"
			end
			if char == "[" or char == "]" then
				open, close = "[ ", " ]"
			end
			if char == "(" or char == ")" then
				open, close = "( ", " )"
			end
			return open, close
		end

		local function find_surrounding(char)
			local open, close = get_pairs(char)
			local open_pat = open:gsub("%p", "%%%1"):gsub(" ", "%%s*")
			local close_pat = close:gsub("%p", "%%%1"):gsub(" ", "%%s*")

			local cursor = vim.api.nvim_win_get_cursor(0)
			local current_row = cursor[1] - 1
			local line = vim.api.nvim_buf_get_lines(0, current_row, current_row + 1, false)[1] or ""
			local cursor_col = cursor[2] + 1

			local start_idx, end_idx
			for s, e in line:gmatch("()" .. open_pat .. ".-" .. close_pat .. "()") do
				if s <= cursor_col and e >= cursor_col then
					start_idx = s
					end_idx = e - 1
					break
				end
			end

			if start_idx and end_idx then
				local MatchStr = line:sub(start_idx, end_idx)
				local precise_open = MatchStr:match("^" .. open_pat) or open
				local precise_close = MatchStr:match(tostring(close_pat) .. "$") or close
				return current_row, start_idx, end_idx, precise_open, precise_close
			end
			return nil
		end

		local target_char = nil

		_G.sandwich_add_operator = function(type)
			if not target_char then
				return
			end

			local open, close = get_pairs(target_char)
			local start_pos = vim.api.nvim_buf_get_mark(0, "[")
			local end_pos = vim.api.nvim_buf_get_mark(0, "]")
			local start_row, start_col = start_pos[1] - 1, start_pos[2]
			local end_row, end_col = end_pos[1] - 1, end_pos[2]

			if type == "line" then
				local line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1] or ""
				start_col = line:match("^%s*"):len()
				end_col = line:len()
			else
				end_col = end_col + 1
			end

			vim.api.nvim_buf_set_text(0, end_row, end_col, end_row, end_col, { close })
			vim.api.nvim_buf_set_text(0, start_row, start_col, start_row, start_col, { open })

			target_char = nil
		end

		binder:map({ "n", "v" }, "sa", function()
			local char = get_char()
			if not char then
				return
			end

			target_char = char

			vim.o.operatorfunc = "v:lua.sandwich_add_operator"

			local mode = vim.api.nvim_get_mode().mode
			local keys
			if mode:match("[vV\22]") then
				keys = vim.api.nvim_replace_termcodes("g@", true, false, true)
			else
				keys = vim.api.nvim_replace_termcodes("g@iw", true, false, true)
			end

			vim.api.nvim_feedkeys(keys, "nt", false)
		end, { silent = true })

		binder:nmap("sd", function()
			local char = get_char()
			if not char then
				return
			end

			local current_row, start_idx, end_idx, precise_open, precise_close = find_surrounding(char)

			if current_row and start_idx and end_idx and precise_open and precise_close then
				vim.api.nvim_buf_set_text(0, current_row, end_idx - #precise_close, current_row, end_idx, {})
				vim.api.nvim_buf_set_text(0, current_row, start_idx - 1, current_row, start_idx - 1 + #precise_open, {})
			end
		end, { silent = true })

		binder:nmap("sr", function()
			local target = get_char()
			if not target then
				return
			end

			local current_row, start_idx, end_idx, precise_open, precise_close = find_surrounding(target)

			if not current_row or not start_idx or not end_idx or not precise_open or not precise_close then
				return
			end

			local ns_id = vim.api.nvim_create_namespace("sandwich_highlight")

			vim.hl.range(
				0,
				ns_id,
				"Visual",
				{ current_row, start_idx - 1 },
				{ current_row, start_idx - 1 + #precise_open }
			)
			vim.hl.range(0, ns_id, "Visual", { current_row, end_idx - #precise_close }, { current_row, end_idx })

			vim.cmd.redraw()

			local replacement = get_char()

			vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)

			if not replacement then
				return
			end
			local r_open, r_close = get_pairs(replacement)

			vim.api.nvim_buf_set_text(0, current_row, end_idx - #precise_close, current_row, end_idx, { r_close })
			vim.api.nvim_buf_set_text(
				0,
				current_row,
				start_idx - 1,
				current_row,
				start_idx - 1 + #precise_open,
				{ r_open }
			)
		end, { silent = true })
	end,
}
