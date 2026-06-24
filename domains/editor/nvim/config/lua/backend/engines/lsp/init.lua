local AdapterScanner = require("backend.shared.AdapterScanner")

---@type Plugin
return {
	"lsp-engine",
	virtual = true,
	ft = AdapterScanner:supported_filetypes("lsp"),
	config = function()
		require("backend.engines.lsp.autocmd").setup()
		require("backend.engines.lsp.config").setup()
	end,
}
