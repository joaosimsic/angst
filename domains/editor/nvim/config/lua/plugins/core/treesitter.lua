return {
	"nvim-treesitter/nvim-treesitter",
	lazy = false,
	config = function()
		vim.treesitter.language.register("blade", "blade")

		vim.filetype.add({
			pattern = {
				[".*%.blade%.php"] = "blade",
			},
		})

		vim.api.nvim_create_autocmd("FileType", {
			pattern = {
				"lua",
				"php",
				"blade",
				"javascript",
				"typescript",
				"c_sharp",
				"java",
				"go",
				"python",
				"css",
				"html",
				"json",
				"markdown",
			},
			callback = function(args)
				local max_filesize = 100 * 1024
				local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
				if ok and stats and stats.size > max_filesize then
					return
				end

				vim.treesitter.start(args.buf)
				vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
