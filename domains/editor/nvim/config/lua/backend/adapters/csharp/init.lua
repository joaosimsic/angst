local function lsp_log_dir()
	local get_log_filename = vim.lsp.log and vim.lsp.log.get_filename
	local log_path = get_log_filename and get_log_filename() or vim.lsp.get_log_path()
	return vim.fs.dirname(log_path)
end

---@type Adapter
return {
	filetypes = { "cs" },
	lsp = "roslyn",
	lsp_cmd = function()
		return {
			"Microsoft.CodeAnalysis.LanguageServer",
			"--logLevel=Information",
			"--extensionLogDirectory=" .. lsp_log_dir(),
			"--stdio",
		}
	end,
	formatter = "csharpier",
	treesitter = { "c_sharp", "razor" },
	lsp_settings = {
		["csharp|inlay_hints"] = {
			csharp_enable_inlay_hints_for_implicit_object_creation = true,
			csharp_enable_inlay_hints_for_implicit_variable_types = true,
			csharp_enable_inlay_hints_for_lambda_parameter_types = true,
			csharp_enable_inlay_hints_for_types = true,
			dotnet_enable_inlay_hints_for_indexer_parameters = true,
			dotnet_enable_inlay_hints_for_literal_parameters = true,
			dotnet_enable_inlay_hints_for_object_creation_parameters = true,
			dotnet_enable_inlay_hints_for_other_parameters = true,
			dotnet_enable_inlay_hints_for_parameters = true,
		},
	},
}
