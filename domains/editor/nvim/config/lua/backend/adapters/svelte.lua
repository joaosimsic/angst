---@type Adapter
return {
	filetypes = { "svelte" },
	lsp = "svelte",
	lsp_cmd = { "svelteserver", "--stdio" },
	formatter = "svelte-biome-format",
	formatter_cmd = { "svelte-biome-format", "$FILENAME" },
	linter = "svelte-biome-lint",
	linter_def = {
		["svelte-biome-lint"] = {
			cmd = "svelte-biome-lint",
			stdin = false,
			ignore_exitcode = true,
			parser = function(output, bufnr)
				local ok, data = pcall(vim.json.decode, output)
				if not ok or type(data) ~= "table" or type(data.diagnostics) ~= "table" then
					return {}
				end

				local buffer_path = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
				local severity = {
					error = vim.diagnostic.severity.ERROR,
					warning = vim.diagnostic.severity.WARN,
					info = vim.diagnostic.severity.INFO,
				}
				local diagnostics = {}

				for _, item in ipairs(data.diagnostics) do
					local location = item.location
					if location and vim.fs.normalize(location.path) == buffer_path then
						diagnostics[#diagnostics + 1] = {
							lnum = location.start.line - 1,
							col = location.start.column - 1,
							end_lnum = location["end"].line - 1,
							end_col = location["end"].column - 1,
							severity = severity[item.severity] or vim.diagnostic.severity.INFO,
							message = item.message,
							code = item.category,
							source = "biome",
						}
					end
				end

				return diagnostics
			end,
		},
	},
	treesitter = "svelte",
}
