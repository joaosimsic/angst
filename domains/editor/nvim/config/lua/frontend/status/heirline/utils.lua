local M = {}

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
