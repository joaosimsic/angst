local AdapterScanner = require("backend.shared.AdapterScanner")
local treesitter_opts = { check_executable = false }
local fold_disabled_filetypes = {
	php = true,
}

---@type Plugin
return {
	"treesitter",
	virtual = true,
	ft = AdapterScanner:supported_filetypes("treesitter", treesitter_opts),
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
			callback = function(event)
				local filetype = vim.bo[event.buf].filetype
				local supported = AdapterScanner:supports_filetype("treesitter", filetype, treesitter_opts)

				if vim.bo[event.buf].buftype ~= "" then
					return
				end

				if not supported then
					return
				end

				local ok = pcall(vim.treesitter.start, event.buf)

				if ok and not fold_disabled_filetypes[filetype] then
					vim.wo.foldmethod = "expr"
					vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
					vim.wo.foldlevel = 99
				end
			end,
		})
	end,
}
