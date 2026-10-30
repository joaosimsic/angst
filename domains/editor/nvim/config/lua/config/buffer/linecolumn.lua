---#type Plugin
return {
	"linecolumn",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local group = vim.api.nvim_create_augroup("LineColumn", { clear = true })

		vim.api.nvim_create_autocmd({ "User", "BufReadPost" }, {
			group = group,
			pattern = { "EditorConfigApplied", "*" },
			callback = function(args)
				if vim.bo[args.buf].buftype ~= "" then
					return
				end

				local buf = args.buf
				local max_line = vim.b[buf].editorconfig and vim.b[buf].editorconfig.max_line_length

				if max_line and tonumber(max_line) > 0 then
					local col = tonumber(max_line)
					vim.opt_local.colorcolumn = string.format("%d,%d", col, col + 1)
					return
				end

				local indent_size = vim.bo[buf].shiftwidth

				if indent_size == 4 then
					vim.opt_local.colorcolumn = "100,101"
					return
				end

				vim.opt_local.colorcolumn = "80,81"
			end,
		})
	end,
}
