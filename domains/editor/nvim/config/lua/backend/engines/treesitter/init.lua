return {
	"nvim-treesitter/nvim-treesitter",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		vim.opt.runtimepath:prepend(vim.fn.expand("~/.local/share/tree-sitter"))

		require("nvim-treesitter").setup({
			sync_install = false,
			auto_install = false,
			highlight = {
				enable = true,
				additional_vim_regex_highlighting = false,
			},
			indent = {
				enable = true,
			},
		})
	end,
}
