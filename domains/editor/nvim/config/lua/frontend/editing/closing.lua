---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"closing",
	virtual = true,
	event = "InsertEnter",
	config = function()
		local binder = Keybinder.new(nil, "CLOSING")
		local bracket_pairs = {
			["("] = ")",
			["["] = "]",
			["{"] = "}",
			['"'] = '"',
			["'"] = "'",
			["`"] = "`",
		}

		local function get_surroundings()
			local line = vim.api.nvim_get_current_line()
			local col = vim.api.nvim_win_get_cursor(0)[2]
			return line:sub(col, col), line:sub(col + 1, col + 1), line
		end

		for open, close in pairs(bracket_pairs) do
			binder:imap(open, function()
				local _, after = get_surroundings()

				if open == close and after == close then
					return "<Right>"
				end

				if after:match("%w") then
					return open
				end

				return open .. close .. "<Left>"
			end, { expr = true, replace_keycodes = true, desc = "Auto-close " .. open })

			if open ~= close then
				binder:imap(close, function()
					local _, after = get_surroundings()
					return after == close and "<Right>" or close
				end, { expr = true, replace_keycodes = true, desc = "Skip " .. close })
			end
		end

		binder:imap("<CR>", function()
			local before, after = get_surroundings()

			if (before == "{" and after == "}") or (before == "[" and after == "]") then
				return "<CR><C-o>O"
			end

			if before == "(" and after == ")" then
				return "<CR><CR><Up><Tab>"
			end

			return "\r"
		end, { expr = true, replace_keycodes = true, desc = "Expand pair on Enter" })

		binder:imap(">", function()
			local _, _, line = get_surroundings()
			local col = vim.api.nvim_win_get_cursor(0)[2]
			local before_cursor = line:sub(1, col)

			local tag = before_cursor:match("<([%w%-]+)%s*[^>]*$")

			if tag then
				return ">" .. "</" .. tag .. ">" .. string.rep("<Left>", #tag + 3)
			end
			return ">"
		end, { expr = true, replace_keycodes = true, desc = "Auto-close HTML/XML tag" })

		binder:imap("<BS>", function()
			local before, after = get_surroundings()
			if bracket_pairs[before] == after then
				return "<BS><Del>"
			end
			return "<BS>"
		end, { expr = true, replace_keycodes = true, desc = "Delete empty pair" })
	end,
}
