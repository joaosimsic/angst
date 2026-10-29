local Logger = require("common.Logger")
local LspTool = require("backend.shared.LspTool")

local root_markers = { "pom.xml", "build.gradle", ".git" }

local logger = Logger.new("LSP")

---@type Adapter
return {
	filetypes = { "java" },
	lsp = "jdtls",
	lsp_cmd = { "jdtls" },
	lsp_root_markers = root_markers,
	lsp_root_dir = LspTool.make_root_dir_finder(root_markers),
	linter = "checkstyle",
	linter_cmd = { "checkstyle", "-c", "/sun_checks.xml" },
	formatter = "google-java-format",
	formatter_cmd = { "google-java-format", "-" },
	treesitter = "java",
	lsp_settings = {
		java = {
			inlayHints = {
				parameterNames = { enabled = "all" },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = true },
			},
		},
	},
	lsp_handlers = {
		["language/status"] = function(_, result, ctx)
			if result.type ~= "ServiceReady" then
				return
			end

			local clients = vim.lsp.get_clients({ id = ctx.client_id })
			local client = clients[1]

			if not client then
				return
			end

			for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
				if vim.lsp.buf_is_attached(bufnr, client.id) then
					logger:info(function()
						return string.format("%s ServiceReady: refreshing inlay hints for bufnr=%d", client.name, bufnr)
					end)
					vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
					vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
				end
			end
		end,
	},
	compiler = "javac",
	compiler_cmd = { "sh", "-c", "javac $FILE && java -cp /tmp $(basename $FILE .java)" },
}
