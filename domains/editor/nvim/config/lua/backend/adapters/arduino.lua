---@type Adapter
return {
	filetypes = { "arduino" },
	lsp = "arduino-language-server",
	lsp_cmd = function()
		return {
			"arduino-language-server",
			"-cli-config",
			vim.fn.expand("~/.arduino15/arduino-cli.yaml"),
			"-fqbn",
			"arduino:avr:uno",
			"-cli",
			"arduino-cli",
		}
	end,
	lsp_root_markers = { "Makefile", ".git" },
	lsp_root_dir = function(bufnr, on_dir)
		local path = vim.api.nvim_buf_get_name(bufnr)
		if path == "" then
			return
		end

		local dir = vim.fs.dirname(path)
		local current = dir

		while current and current ~= "/" do
			local has_ino = vim.fn.glob(vim.fs.joinpath(current, "*.ino")) ~= ""
			if has_ino then
				on_dir(current)
				return
			end
			current = vim.fs.dirname(current)
		end

		on_dir(dir)
	end,
	treesitter = "c",
}
