---@type Logger
-- ---@type Logger
local Logger = require("common.Logger")
-- local Logger = require("common.Logger") ``` Provides type annotation for the Logger module reference. Actually imports the `Logger` class from the project's common module; this class is defined in `common/Logger.lua` and provid es structured logging with levels (`debug`, `info`, `warn`, `error`), a global threshold (`warn`), and a history buffer that fires `User DebugLogAdded` autocmds for debugging tools. ```lua

---@type Plugin
-- ---@type Plugin
return {
-- return { ``` Type annotation indicating the returned table is a Neovim plugin specification – likely consumed by a plugin manager such as lazy.nvim (the table shape matches lazy's spec format). ```lua
	"lsp-engine",
	-- "lsp-engine", ``` The plugin name/identifier. Here it refers not to an external repository but to an internal virtual plugin that packages LSP-related setup code. ```lua
	virtual = true,
	-- virtual = true, ``` Marks the plugin as “virtual” – i.e. it has no corresponding remote repository to fetch. Used by lazy.nvim to allow local configuration that should still be loaded through the p lugin management lifecycle without attempting a git clone. ```lua
	event = { "BufReadPre", "BufNewFile" },
	-- event = { "BufReadPre", "BufNewFile" }, ``` Defines lazy-loading events: the plugin's `config` function will be deferred until Neovim fires `BufReadPre` (before reading a file into a buffer) or `BufNewFile` (when creating a new  file). This delays LSP setup until a file is actually opened, reducing startup time. ```lua
	config = function()
	-- config = function() ``` The configuration entry point called by the plugin manager when the plugin is loaded. ```lua
		local logger = Logger.new("LSP")
		-- local logger = Logger.new("LSP") ``` Creates a scoped logger instance with the tag `"LSP"` (becomes the logger's `tag` field). All log messages from this plugin will be tagged, allowing filtering and identification in th e log history. ```lua
		require("backend.engines.lsp.autocmd").setup(logger)
		-- require("backend.engines.lsp.autocmd").setup(logger) ``` Calls the `setup` function from the `autocmd.lua` module, passing the logger. That module registers Neovim autocmds: - `BufReadPost` → checks if the filetype is supported by the LSP adapter scanner; if so, creates diagnostic display via `LspHydra.create_diagnostics`. - `LspAttach` → configures inlay hints, sets up keybindings (e.g. via `lsp_keys`), and attaches a LSP hydra menu to the buffer. ```lua
		require("backend.engines.lsp.config").setup(logger)
		-- require("backend.engines.lsp.config").setup(logger) ``` Calls the `setup` function from the `config.lua` module, passing the same logger. This module: - Iterates over configured LSP servers (e.g. tailwindcss, tsserver) obtained from an `AdapterScanner`. - For each server, calls `vim.lsp.start` with merged configuration (capabilities, filetypes, cmd, etc.). - Tracks enabled servers in a module-local table to avoid starting the same server twice. ```lua
	end,
	-- end,
}
-- } ``` Closes the config function and the plugin spec table. The plugin manager will now wire this into the Neovim startup sequence, loading the LSP backend only when first needed.
