local Logger = require("common.Logger")

local logger = Logger.new("LSP")

local function find_workspace_root(bufnr, on_dir)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		return
	end

	local dir = vim.fs.dirname(path)
	while dir do
		local manifest = io.open(dir .. "/Cargo.toml", "r")
		if manifest then
			local text = manifest:read("a") or ""
			manifest:close()
			if text:match("%[workspace%]") then
				on_dir(dir)
				return
			end
		end
		local parent = vim.fs.dirname(dir)
		if parent == dir then
			break
		end
		dir = parent
	end

	on_dir(vim.fs.root(path, { "Cargo.toml", ".git" }) or vim.fs.dirname(path))
end

---@type Adapter
return {
	filetypes = { "rust" },
	lsp = "rust_analyzer",
	lsp_cmd = function()
		if vim.fn.executable("rust-analyzer-mux") == 1 then
			return { "rust-analyzer-mux" }
		end
		return { "rust-analyzer" }
	end,
	lsp_root_dir = find_workspace_root,
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
