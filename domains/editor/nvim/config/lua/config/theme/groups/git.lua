local palette = require("config.theme.palette")
local p, a = palette.p, palette.a

local M = {}

---@return HighlightGroups
M.get = function()
	return {
		DiffAdd = { fg = a.success, bg = p.background.variant },
		DiffChange = { fg = a.warn, bg = p.background.variant },
		DiffDelete = { fg = a.error, bg = p.background.variant },
		DiffText = { fg = p.foreground.variant, bg = p.background.variant, bold = true },

		GitSignsAdd = { fg = a.success },
		GitSignsChange = { fg = a.warn },
		GitSignsDelete = { fg = a.error },
		GitSignsUntracked = { fg = p.dim },

		DiffviewNormal = { link = "Normal" },
		DiffviewCursorLine = { link = "CursorLine" },
		DiffviewWinSeparator = { link = "WinSeparator" },
		DiffviewFilePanelTitle = { fg = p.foreground.variant, bold = true },
		DiffviewFilePanelCounter = { fg = p.dim },
		DiffviewFilePanelFileName = { fg = p.foreground.base },
		DiffviewDiffAdd = { link = "DiffAdd" },
		DiffviewDiffDelete = { link = "DiffDelete" },
		DiffviewDiffChange = { link = "DiffChange" },
		DiffviewDiffText = { link = "DiffText" },

		NeogitBranch = { fg = a.info, bold = true },
		NeogitRemote = { fg = p.accent.base },
		NeogitHunkHeader = { fg = p.foreground.variant, bg = p.background.variant, bold = true },
		NeogitHunkHeaderHighlight = { fg = p.foreground.variant, bg = p.background.variant, bold = true },
		NeogitDiffAdd = { link = "DiffAdd" },
		NeogitDiffDelete = { link = "DiffDelete" },
		NeogitDiffContextHighlight = { link = "CursorLine" },
		NeogitNotificationInfo = { fg = a.info },
		NeogitNotificationWarning = { fg = a.warn },
		NeogitNotificationError = { fg = a.error },

		gitcommitSummary = { fg = p.foreground.variant, bold = true },
		gitcommitOverflow = { fg = a.error },
		gitcommitBlank = { fg = p.dim },
		gitcommitComment = { fg = p.dim, italic = true },
		gitcommitSelected = { fg = a.success },
		gitcommitSelectedFile = { fg = a.success },
		gitcommitSelectedType = { fg = a.success, bold = true },
		gitcommitDiscarded = { fg = a.error },
		gitcommitDiscardedFile = { fg = a.error },
		gitcommitDiscardedType = { fg = a.error, bold = true },
		gitcommitUntracked = { fg = a.warn },
		gitcommitUntrackedFile = { fg = a.warn },
		gitcommitBranch = { fg = a.info, bold = true },
		gitcommitHeader = { fg = p.accent.base },
		gitcommitOnBranch = { fg = p.dim },
		gitcommitType = { fg = p.accent.base },
		gitcommitArrow = { fg = p.dim },
		gitcommitFile = { fg = p.foreground.base },

		GitCommitKey = { fg = p.accent.base, bold = true },
		GitCommitAction = { fg = p.foreground.variant },
		GitCommitModified = { fg = a.warn, bold = true },
		GitCommitNewFile = { fg = a.success, bold = true },
		GitCommitDeleted = { fg = a.error, bold = true },
		GitCommitRenamed = { fg = p.accent.base, bold = true },
	}
end

return M
