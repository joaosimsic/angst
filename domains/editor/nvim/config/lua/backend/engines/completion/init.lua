return {
	"saghen/blink.cmp",
  version = "1.*",
	config = function()
		require("backend.engines.completion.config").setup()
	end,
}
