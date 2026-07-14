local Logger = require("common.Logger")
local LspTool = require("backend.shared.LspTool")

local root_markers = { "Cargo.toml", ".git" }

local logger = Logger.new("LSP")

---@type Adapter
return {
	filetypes = { "rust" },
	lsp = "rust_analyzer",
	lsp_cmd = { "rust-analyzer" },
	lsp_root_dir = LspTool.make_root_dir_finder(root_markers),
	linter = "clippy",
	linter_cmd = { "cargo-clippy" },
	formatter = "rustfmt",
	treesitter = "rust",
	lsp_settings = {
		["rust-analyzer"] = {
			check = { command = "clippy" },
			inlayHints = {
				chainingHints = { enable = true },
				parameterHints = { enable = true },
				typeHints = { enable = true },
			},
		},
	},
	lsp_handlers = {
		["experimental/serverStatus"] = function(_, result, ctx)
			if not result or not result.quiescent then
				return
			end

			local client = vim.lsp.get_client_by_id(ctx.client_id)
			if not client then
				return
			end

			for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
				if vim.lsp.buf_is_attached(bufnr, client.id) then
					if vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }) and not vim.b[bufnr].lsp_inlay_verified then
						logger:info(function()
							return string.format(
								"%s quiescent: refreshing inlay hints for bufnr=%d",
								client.name,
								bufnr
							)
						end)
						vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
						vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
					end
				end
			end
		end,
	},
	compiler = "rustc",
	compiler_cmd = { "sh", "-c", "rustc $FILE -o /tmp/scratch_out 2>&1 && /tmp/scratch_out" },
}
