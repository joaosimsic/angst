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
		build = function()
			local app_dir = vim.fn.stdpath("data") .. "/lazy/markdown-preview.nvim/app"
			vim.system({ "rm", "-rf", "node_modules" }, { cwd = app_dir }):wait()
			vim.system({ "npm", "install" }, { cwd = app_dir }):wait()
		end,
		init = function()
			vim.g.mkdp_filetypes = { "markdown" }
		end,
		config = function()
			local Badge = require("common.Badge")
			local Keybinder = require("common.Keybinder")
			local palette = require("config.theme.palette")
			local p = palette.p
			local md_badge = Badge.new({
				name = "md-preview",
				fg = p.background.base,
				bg = p.surface.base,
			})
			local preview_active = false

			local group = vim.api.nvim_create_augroup("MarkdownPreview", { clear = true })

			vim.api.nvim_create_autocmd("BufEnter", {
				group = group,
				pattern = "*.md",
				callback = function()
					vim.api.nvim_buf_create_user_command(0, "MarkdownPreviewToggle", function()
						preview_active = not preview_active
						vim.fn["mkdp#util#toggle_preview"]()
						if preview_active then
							md_badge:show("md-preview", "MD Preview")
						else
							md_badge:hide("md-preview")
						end
					end, { force = true })
				end,
			})

			vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete", "BufWipeout" }, {
				group = group,
				pattern = "*.md",
				callback = function()
					if preview_active then
						preview_active = false
						md_badge:hide("md-preview")
					end
				end,
			})

			local binder = Keybinder.new(nil, "MD_PREVIEW")
			binder:nmap("<leader>mp", function()
				vim.cmd("MarkdownPreviewToggle")
			end, { desc = "Toggle markdown preview" })
		end,
	},
}
