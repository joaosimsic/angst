---@type Plugin[]
return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = "markdown",
		opts = {},
	},
	{
		"iamcco/markdown-preview.nvim",
		ft = "markdown",
		build = "cd app && npm install",
		init = function()
			vim.g.mkdp_filetypes = { "markdown" }
		end,
		config = function()
			local Badge = require("common.Badge")
			local md_badge = Badge.new("md-preview")

			local preview_active = false

			vim.api.nvim_create_user_command("MarkdownPreviewToggle", function()
				preview_active = not preview_active
				vim.fn["mkdp#preview#toggle"]()
				if preview_active then
					md_badge:show("md-preview", "MD Preview")
				else
					md_badge:hide("md-preview")
				end
			end, { force = true })
		end,
	},
}
