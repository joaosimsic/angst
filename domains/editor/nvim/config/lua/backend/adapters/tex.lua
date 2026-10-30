---@type Adapter
return {
	filetypes = { "tex", "plaintex", "bib", "latex" },
	lsp = "texlab",
	lsp_cmd = { "texlab" },
	lsp_root_markers = { ".latexmkrc", ".texlabroot", "texlab.toml", ".git", "main.tex" },
	formatter = "latexindent",
	linter = "chktex",
	treesitter = { "latex", "bibtex" },
	compiler = "latexmk",
	compiler_cmd = { "latexmk", "-pdf", "-interaction=nonstopmode", "-cd", "$FILE" },
	lsp_settings = {
		texlab = {
			chktex = {
				onOpenAndSave = true,
				onEdit = false,
			},
			latexFormatter = "latexindent",
			bibtexFormatter = "latexindent",
			latexindent = {
				modifyLineBreaks = false,
			},
			build = {
				onSave = false,
			},
		},
	},
}
