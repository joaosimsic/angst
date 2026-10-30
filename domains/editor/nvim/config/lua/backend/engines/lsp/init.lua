---@type Logger
local Logger = require("common.Logger")

---@type Plugin
return {
	"lsp-engine",
	virtual = true,
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local logger = Logger.new("LSP")
		require("backend.engines.lsp.autocmd").setup(logger)
		require("backend.engines.lsp.config").setup(logger)
	end,
}
