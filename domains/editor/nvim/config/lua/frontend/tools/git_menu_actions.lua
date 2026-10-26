-- Plain { label, run, needs_git } list for the <leader>G git menu.
-- Kept separate from the picker spec so tests can require it headless.

---@class GitMenuAction
---@field label string
---@field run fun()
---@field needs_git boolean

---@return GitMenuAction[]
local function actions()
	return {
		{
			label = "status: open Neogit tab",
			needs_git = false,
			run = function()
				vim.cmd("Neogit")
			end,
		},
		{
			label = "commit",
			needs_git = false,
			run = function()
				vim.cmd("Neogit commit")
			end,
		},
		{
			label = "log",
			needs_git = false,
			run = function()
				vim.cmd("Neogit log")
			end,
		},
		{
			label = "review: working tree",
			needs_git = false,
			run = function()
				vim.cmd("DiffviewOpen")
			end,
		},
		{
			label = "review: PR range against base",
			needs_git = false,
			run = function()
				vim.ui.input({ prompt = "Diff base: ", default = "origin/main" }, function(base)
					if base ~= nil and base ~= "" then
						vim.cmd("DiffviewOpen " .. base .. "...HEAD")
					end
				end)
			end,
		},
		{
			label = "history: current file",
			needs_git = false,
			run = function()
				local file = vim.fn.expand("%")
				if file == "" then
					vim.notify("Git menu: no file in current buffer", vim.log.levels.WARN)
					return
				end
				vim.cmd("DiffviewFileHistory " .. vim.fn.fnameescape(file))
			end,
		},
		{
			label = "history: all files",
			needs_git = false,
			run = function()
				vim.cmd("DiffviewFileHistory")
			end,
		},
		{
			label = "close diff review",
			needs_git = false,
			run = function()
				vim.cmd("DiffviewClose")
			end,
		},
		{
			label = "hunk: preview",
			needs_git = true,
			run = function()
				vim.cmd("Gitsigns preview_hunk_inline")
			end,
		},
		{
			label = "hunk: blame line",
			needs_git = true,
			run = function()
				vim.cmd("Gitsigns blame_line full=true")
			end,
		},
		{
			label = "hunk: diff this file",
			needs_git = true,
			run = function()
				vim.cmd("Gitsigns diffthis")
			end,
		},
		{
			label = "hunks: send all to quickfix",
			needs_git = true,
			run = function()
				vim.cmd("Gitsigns setqflist all")
			end,
		},
	}
end

return actions()
