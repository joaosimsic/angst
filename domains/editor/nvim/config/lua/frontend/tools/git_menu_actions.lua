-- Plain { label, run, needs_git } list for the <leader>gl git menu.
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
			label = "hunk: preview",
			needs_git = true,
			run = function()
				vim.cmd("Gitsigns preview_hunk")
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
	}
end

return actions()
