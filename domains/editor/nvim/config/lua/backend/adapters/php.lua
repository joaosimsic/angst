local root_markers = { "composer.json", ".phpactor.json", ".phpactor.yml", ".git" }

local function root_dir(bufnr, on_dir)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		return
	end

	on_dir(vim.fs.root(path, root_markers) or vim.fs.dirname(path))
end

---@type Adapter
return {
	filetypes = { "php" },
	lsp = "phpactor",
	lsp_cmd = { "phpactor", "language-server" },
	lsp_root_markers = root_markers,
	lsp_root_dir = root_dir,
	formatter = "php_cs_fixer",
	formatter_cmd = {
		"php-cs-fixer",
		"fix",
		"$FILENAME",
		"--rules=@PSR12",
		"--using-cache=no",
		"--show-progress=none",
		"-q",
	},
	linter = "phpstan",
	linter_cmd = { "phpstan", "analyze", "--level=max", "--error-format=json", "--no-progress" },
	treesitter = "php",
	lsp_init_options = {
		["language_server_worse_reflection.inlay_hints.enable"] = true,
		["language_server_worse_reflection.inlay_hints.params"] = true,
		["language_server_worse_reflection.inlay_hints.types"] = true,
	},
}
