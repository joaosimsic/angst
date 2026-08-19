---@type Adapter
return {
	filetypes = { "c", "cpp" },
	lsp = "clangd",
	lsp_cmd = function()
		local gpp = vim.fn.exepath("g++")
		local cmd = { "clangd" }
		if gpp ~= "" then
			table.insert(cmd, "--query-driver=" .. gpp)
		end
		return cmd
	end,
	formatter = "clang-format",
	linter = "clang-tidy",
	linter_def = {
		["clang-tidy"] = {
			cmd = "clang-tidy",
			stdin = false,
			args = { "-quiet" },
			ignore_exitcode = true,
			pattern = "^(.+):(%d+):(%d+): (%a+): (.+) %[(.+)%]",
			captures = { "file", "lnum", "col", "severity", "message", "code" },
			severity = {
				error = vim.diagnostic.severity.ERROR,
				warning = vim.diagnostic.severity.WARN,
				note = vim.diagnostic.severity.INFO,
			},
		},
	},
	treesitter = { "c", "cpp" },
	compiler = { "gcc", "g++" },
	compiler_cmd = {
		gcc = { "sh", "-c", "gcc $FILE -o /tmp/scratch_out 2>&1 && /tmp/scratch_out" },
		["g++"] = { "sh", "-c", "g++ $FILE -o /tmp/scratch_out 2>&1 && /tmp/scratch_out" },
	},
}
