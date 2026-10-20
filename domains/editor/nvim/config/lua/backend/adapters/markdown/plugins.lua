local Badge = require("common.Badge")
local Keybinder = require("common.Keybinder")
local palette = require("config.theme.palette")
local p = palette.p

local source_path = debug.getinfo(1, "S").source:gsub("^@", "")
local plugin_dir = vim.fn.fnamemodify(source_path, ":p:h") .. "/markdown-preview.nvim"

vim.g.angst_mkdp_root_dir = plugin_dir

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
			vim.g.mkdp_open_to_the_world = 1
			vim.g.mkdp_echo_preview_url = 1
			vim.g.mkdp_browserfunc = "OpenPreviewOnHost"
			vim.g.mkdp_auto_close = 0
			vim.g.mkdp_combine_preview = 1
			vim.g.mkdp_combine_preview_auto_refresh = 1

			vim.cmd([[
				function! OpenPreviewOnHost(url) abort
					echomsg "MD Preview: " . a:url
					call jobstart(['xdg-open', a:url])
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
					vim.g.mkdp_linked_bufnr = nil
					if preview_active then
						preview_active = false
						md_badge:hide("md-preview")
					end
				end,
			})

			vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
				group = group,
				callback = function()
					if not vim.tbl_contains({ "markdown", "markdown.mdx" }, vim.bo.filetype) then
						return
					end
					vim.api.nvim_buf_create_user_command(0, "MarkdownPreviewToggle", function()
						require("mkdp").toggle_preview()
					end, { force = true })

					local bufnr = vim.api.nvim_get_current_buf()
					if require("mkdp.rpc").get_server_status() == 1 and vim.g.mkdp_linked_bufnr ~= bufnr then
						vim.g.mkdp_linked_bufnr = bufnr
						vim.b.MarkdownPreviewToggleBool = 1
						require("mkdp").open_browser()
					end
				end,
			})

			local binder = Keybinder.new(nil, "MD_PREVIEW")
			binder:nmap("<leader>mp", function()
				require("mkdp").toggle_preview()
			end, { desc = "Toggle markdown preview" })
		end,
	},
}
