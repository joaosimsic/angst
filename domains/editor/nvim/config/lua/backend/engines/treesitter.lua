return {
	"treesitter",
	virtual = true,
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		vim.opt.runtimepath:prepend(vim.fn.expand("~/.local/share/tree-sitter"))

		local grammar_mappings = {
			cs = "c_sharp",
			razor = "c_sharp",
			sh = "bash",
			bash = "bash",
		}

		for filetype, grammar in pairs(grammar_mappings) do
			vim.treesitter.language.register(grammar, filetype)
		end

    local group = vim.api.nvim_create_augroup("TreesitterInit", { clear = true })

		vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
      group = group,
			pattern = "*",
			callback = function()
				local ok, _ = pcall(vim.treesitter.start)

				if ok then
					vim.wo.foldmethod = "expr"
					vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
          vim.wo.foldlevel = 99
				end
			end,
		})
	end,
}
