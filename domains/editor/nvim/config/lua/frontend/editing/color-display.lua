---@type Plugin
return {
	"color-display",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local ns_id = vim.api.nvim_create_namespace("InlineColorizer")

		local hex_pattern = "#%x%x%x%x%x%x?%x?%x?"

		local function colorize_visible_buffer()
			local bufnr = vim.api.nvim_get_current_buf()

			vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

			local start_line = vim.fn.line("w0") - 1
			local end_line = vim.fn.line("w$")

			if start_line < 0 or end_line <= 0 then
				return
			end

			local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

			for i, line in ipairs(lines) do
				local current_line_num = start_line + i - 1
				local start_idx = 1

				while true do
					local s, e = line:find(hex_pattern, start_idx)
					if not s or not e then
						break
					end

					local hex = line:sub(s, e)

					if #hex == 4 or #hex == 7 or #hex == 9 then
						local hl_group = "ColorBox_" .. hex:gsub("#", "")
						vim.api.nvim_set_hl(0, hl_group, { fg = hex, bg = "NONE" })

						vim.api.nvim_buf_set_extmark(bufnr, ns_id, current_line_num, e, {
							virt_text = { { " ■", hl_group } },
							virt_text_pos = "inline",
						})
					end

					start_idx = e + 1
				end
			end
		end

		vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWinEnter", "WinScrolled" }, {
			group = vim.api.nvim_create_augroup("InlineColorizerGroup", { clear = true }),
			callback = function()
				colorize_visible_buffer()
			end,
		})

		colorize_visible_buffer()
	end,
}
