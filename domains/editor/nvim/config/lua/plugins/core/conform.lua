local manifest = require("config.manifest")

return {
	"stevearc/conform.nvim",
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>f",
			function()
				require("conform").format({ async = false, lsp_fallback = true, timeout_ms = 1000 })
			end,
			desc = "Format File",
			mode = "n",
		},
	},
	opts = {
		formatters_by_ft = manifest.tools.formatters,
		formatters = {
			["google-java-format"] = {
				command = "google-java-format",
			},
		},
	},
}
