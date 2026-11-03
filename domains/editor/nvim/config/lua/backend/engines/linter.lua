---@type Plugin
return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },

	config = function()
		local AdapterScanner = require("backend.shared.AdapterScanner")
		local linter_opts = { check_executable = true }
		local lint = require("lint")
		lint.linters_by_ft = AdapterScanner:by_filetype("linter", linter_opts)

		local golangci_builtin = require("lint.linters.golangcilint")

		local function golangci_args(target)
			local version = vim.fn.system({ "golangci-lint", "version" })

			if version:find("version v1") or version:find("version 1") then
				return {
					"run",
					"--out-format",
					"json",
					"--issues-exit-code=0",
					"--show-stats=false",
					"--print-issued-lines=false",
					"--print-linter-name=false",
					target,
				}
			end

			local args = {
				"run",
				"--output.json.path=stdout",
				"--output.text.path=",
				"--output.tab.path=",
				"--output.html.path=",
				"--output.checkstyle.path=",
				"--output.code-climate.path=",
				"--output.junit-xml.path=",
				"--output.teamcity.path=",
				"--output.sarif.path=",
				"--issues-exit-code=0",
				"--show-stats=false",
			}

			if not (version:find("version v2.0.") or version:find("version 2.0.")) then
				table.insert(args, "--path-mode=abs")
			end

			table.insert(args, target)
			return args
		end

		lint.linters.golangcilint = function()
			local file = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
			local root = vim.fs.root(file, { "go.work", "go.mod" }) or vim.fn.fnamemodify(file, ":h")

			return {
				cmd = "golangci-lint",
				args = golangci_args(vim.fs.dirname(file)),
				cwd = root,
				append_fname = false,
				stream = "stdout",
				parser = golangci_builtin.parser,
			}
		end

		for _, adapter in pairs(AdapterScanner:adapters()) do
			if adapter.linter_def then
				for name, def in pairs(adapter.linter_def) do
					if not lint.linters[name] then
						lint.linters[name] = {
							cmd = def.cmd,
							stdin = def.stdin,
							args = def.args,
							ignore_exitcode = def.ignore_exitcode,
							parser = require("lint.parser").from_pattern(def.pattern, def.captures, def.severity),
						}
					end
				end
			end
		end

		local clippy = lint.linters.clippy
		if clippy then
			clippy.ignore_exitcode = true
		end

		local group = vim.api.nvim_create_augroup("LinterWatch", { clear = true })

		vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter" }, {
			group = group,
			callback = function(event)
				local filetype = vim.bo[event.buf].filetype

				if filetype == "" or vim.bo[event.buf].buftype ~= "" then
					return
				end

				if not AdapterScanner:supports_filetype("linter", filetype, linter_opts) then
					return
				end

				lint.try_lint(nil, {
					ignore_errors = true,
				})
			end,
		})
	end,
}
