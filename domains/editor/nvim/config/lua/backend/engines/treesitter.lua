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

		local ts_queries_base = vim.fn.expand("~/.local/share/tree-sitter")
		if not vim.tbl_contains(vim.opt.runtimepath:get(), ts_queries_base) then
			vim.opt.runtimepath:prepend(ts_queries_base)
		end

		vim.opt.runtimepath:remove(vim.fn.stdpath("config"))
		vim.opt.runtimepath:prepend(vim.fn.stdpath("config"))

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

				logger:info(function()
					return string.format(
						"Filetype [%s] resolved to Tree-sitter language parser string: [%s]",
						filetype,
						lang
					)
				end)

				local has_parser, parser_err = pcall(vim.treesitter.language.add, lang)
				if not has_parser then
					logger:error(function()
						return string.format("Missing parser binary for language [%s]: %s", lang, parser_err)
					end)
					return
				end

				local query_files = vim.treesitter.query.get_files(lang, "highlights")

				if not query_files or #query_files == 0 then
					logger:error(function()
						return string.format(
							"CRITICAL: No query highlight files found anywhere for language parser [%s]",
							lang
						)
					end)
				else
					local using_custom_query = false
					for _, path in ipairs(query_files) do
						if path:find(".local/share/tree-sitter", 1, true) then
							using_custom_query = true
						end
					end

					if not using_custom_query then
						logger:error(function()
							return string.format(
								"Language [%s] queries found, but NONE from your custom folder! Neovim picked up: %s",
								lang,
								vim.inspect(query_files)
							)
						end)
					else
						logger:info(function()
							return string.format("Success! Loaded queries for [%s] from your shared path.", lang)
						end)
					end
				end

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

		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			local ft = vim.bo[buf].filetype
			if vim.bo[buf].buftype == "" and AdapterScanner:supports_filetype("treesitter", ft, treesitter_opts) then
				local lang = vim.treesitter.language.get_lang(ft) or ft
				local has_parser, _ = pcall(vim.treesitter.language.add, lang)
				if has_parser then
					pcall(vim.treesitter.start, buf, lang)
				end
			end
		end
	end,
}
