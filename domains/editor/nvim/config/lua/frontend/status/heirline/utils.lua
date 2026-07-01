local M = {}

---@param hex string|nil
---@param factor number
---@return string|nil
M.apply_dark_filter = function(hex, factor)
	if hex == nil then
		return nil
	end

	hex = hex:gsub("#", "")
	if #hex ~= 6 then
		return "#000000"
	end

	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)

	if r == nil or g == nil or b == nil then
		return "#000000"
	end

	r = math.floor(r * factor)
	g = math.floor(g * factor)
	b = math.floor(b * factor)

	return string.format("#%02x%02x%02x", r, g, b)
end

---@param self table
---@return boolean
M.is_active = function(self)
	if self.is_active ~= nil then
		return self.is_active
	end
	if vim.g.terminal_focused == false then
		return false
	end
	return vim.api.nvim_get_current_win() == vim.g.statusline_winid
end

---@param self table
---@param color string|nil
---@return string|nil
M.status_color = function(self, color)
	if not M.is_active(self) then
		return M.apply_dark_filter(color, 0.65)
	end

	return color
end

---@param self table
---@param color string
---@return string
M.status_bg = function(self, color)
	return self.bg or M.status_color(self, color) or color
end

---@param str string
---@return string
M.to_small_caps = function(str)
	local small_caps_map = {
		A = "ᴀ",
		B = "ʙ",
		C = "ᴄ",
		D = "ᴅ",
		E = "ᴇ",
		F = "ꜰ",
		G = "ɢ",
		H = "ʜ",
		I = "ɪ",
		J = "ᴊ",
		K = "ᴋ",
		L = "ʟ",
		M = "ᴍ",
		N = "ɴ",
		O = "ᴏ",
		P = "ᴘ",
		Q = "ǫ",
		R = "ʀ",
		S = "s",
		T = "ᴛ",
		U = "ᴜ",
		V = "ᴠ",
		W = "ᴡ",
		X = "x",
		Y = "ʏ",
		Z = "ᴢ",
	}

	local upper_str = string.upper(str)
	local result = ""

	for i = 1, #upper_str do
		local char = upper_str:sub(i, i)
		result = result .. (small_caps_map[char] or char)
	end

	return result
end

return M
