return {
	"nvim-treesitter/nvim-treesitter",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
    local scan_adapters = require("backend.shared.scan_adapters")
		local configs = require("nvim-treesitter.configs")

		local grammars = scan_adapters("treesitter", { check_executable = false })
		local ensure_installed = vim.tbl_keys(grammars)

		configs.setup({
			ensure_installed = ensure_installed,

			sync_install = false,
			auto_install = false,
			parser_install_dir = vim.fn.stdpath("data") .. "/treesitter-parsers",

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
