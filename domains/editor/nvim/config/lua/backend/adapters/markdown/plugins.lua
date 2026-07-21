local Badge = require("common.Badge")
local Keybinder = require("common.Keybinder")
local palette = require("config.theme.palette")
local p = palette.p

local source_path = debug.getinfo(1, "S").source:gsub("^@", "")
local plugin_dir = vim.fn.fnamemodify(source_path, ":p:h") .. "/markdown-preview.nvim"

---@type Plugin[]
return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = "markdown",
		opts = {},
	},
	{
		dir = plugin_dir,
		ft = "markdown",
		build = function()
			vim.system({ "bun", "install" }, { cwd = plugin_dir .. "/app" }):wait()
		end,
		config = function()
			vim.g.mkdp_port = 9093
			vim.g.mkdp_browserfunc = 'MkdpOpenOnHost'

			vim.cmd([[
				function! MkdpOpenOnHost(url) abort
				  call jobstart(['curl', '-s', '-X', 'POST', '-d', a:url, 'http://10.0.2.2:19093/'])
				endfunction
			]])

			local md_badge = Badge.new({
				name = "md-preview",
				fg = p.background.base,
				bg = p.surface.base,
			})
			local preview_active = false

			local group = vim.api.nvim_create_augroup("MarkdownPreview", { clear = true })

			vim.api.nvim_create_autocmd("User", {
				group = group,
				pattern = "MkdpPreviewStart",
				callback = function()
					preview_active = true
					md_badge:show("md-preview", "MD Preview")
				end,
			})

			vim.api.nvim_create_autocmd("User", {
				group = group,
				pattern = "MkdpPreviewStop",
				callback = function()
					if preview_active then
						preview_active = false
						md_badge:hide("md-preview")
					end
				end,
			})

			vim.api.nvim_create_autocmd("BufEnter", {
				group = group,
				pattern = "*.md",
				callback = function()
					vim.api.nvim_buf_create_user_command(0, "MarkdownPreviewToggle", function()
						require("mkdp").toggle_preview()
					end, { force = true })
				end,
			})

			local binder = Keybinder.new(nil, "MD_PREVIEW")
			binder:nmap("<leader>mp", function()
				vim.cmd("MarkdownPreviewToggle")
			end, { desc = "Toggle markdown preview" })
		end,
	},
}
