---@type Logger
local Logger = require("common.Logger")

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
		local logger = Logger.new("TREESITTER")

		local ts_path = vim.fn.expand("~/.local/share/tree-sitter")
		if not vim.tbl_contains(vim.opt.runtimepath:get(), ts_path) then
			vim.opt.runtimepath:prepend(ts_path)
		end

		local grammar_mappings = {
			cs = "c_sharp",
			razor = "c_sharp",
			sh = "bash",
			bash = "bash",
			typescriptreact = "tsx",
		}

		for filetype, grammar in pairs(grammar_mappings) do
			vim.treesitter.language.register(grammar, filetype)
		end

		local group = vim.api.nvim_create_augroup("TreesitterInit", { clear = true })

		vim.api.nvim_create_autocmd("FileType", {
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

				local lang = vim.treesitter.language.get_lang(filetype) or filetype

				local ok, err = pcall(vim.treesitter.start, event.buf, lang)

				if not ok then
					logger:error(function()
						return string.format("Treesitter failed to start for [%s]: %s", filetype, err)
					end)
				end

				if ok and not fold_disabled_filetypes[filetype] then
					vim.wo.foldmethod = "expr"
					vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
					vim.wo.foldlevel = 99
				end
			end,
		})
	end,
}
