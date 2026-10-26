local palette = require("config.theme.palette")
local p, a = palette.p, palette.a

local M = {}

local function hex_to_rgb(hex)
	hex = hex:gsub("#", "")
	return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

-- Muted tint of `fg` over `bg`: keeps code text untouched, only the
-- line background shifts. Same ratio, different hues => 3 distinct bgs.
local function blend(fg_hex, bg_hex, t)
	local fr, fgg, fb = hex_to_rgb(fg_hex)
	local br, bgg, bb = hex_to_rgb(bg_hex)
	local function m(x, y)
		return math.floor(x * t + y * (1 - t) + 0.5)
	end
	return string.format("#%02x%02x%02x", m(fr, br), m(fgg, bgg), m(fb, bb))
end

local add_bg = blend(a.success, p.background.variant, 0.22)
local change_bg = blend(a.warn, p.background.variant, 0.22)
local delete_bg = blend(a.error, p.background.variant, 0.22)

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
		-- Full-line hunk backgrounds: bg-only, code `fg` untouched.
		GitSignsAddLn = { bg = add_bg },
		GitSignsChangeLn = { bg = change_bg },
		GitSignsDeleteLn = { bg = delete_bg },
		GitSignsTopdeleteLn = { link = "GitSignsDeleteLn" },
		GitSignsChangedeleteLn = { link = "GitSignsChangeLn" },
		GitSignsUntrackedLn = { bg = p.background.variant },
		GitSignsStagedAddLn = { link = "GitSignsAddLn" },
		GitSignsStagedChangeLn = { link = "GitSignsChangeLn" },
		GitSignsStagedDeleteLn = { link = "GitSignsDeleteLn" },
		GitSignsAddPreview = { link = "DiffAdd" },
		GitSignsDeletePreview = { link = "DiffDelete" },
		GitSignsChangePreview = { link = "DiffChange" },
		-- Word highlights recolor code text: pin them to the same bg-only
		-- tints so even a stray enable can't change text color.
		GitSignsAddInline = { bg = add_bg },
		GitSignsDeleteInline = { bg = delete_bg },
		GitSignsChangeInline = { bg = change_bg },

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

		NeogitSectionHeader = { fg = p.accent.base, bold = true },
		NeogitSectionHeaderCount = { fg = p.foreground.variant, bold = true },
		NeogitFilePath = { fg = p.foreground.variant, bold = true },
		NeogitChangeModified = { fg = a.warn, bold = true },
		NeogitChangeAdded = { fg = a.success, bold = true },
		NeogitChangeNewFile = { fg = a.success, bold = true },
		NeogitChangeDeleted = { fg = a.error, bold = true },
		NeogitChangeRenamed = { fg = p.accent.base, bold = true },
		NeogitChangeCopied = { fg = a.info },
		NeogitChangeUpdated = { fg = a.info },
		NeogitChangeUnmerged = { fg = a.error, bold = true, underline = true },
		NeogitChangeUntracked = { fg = p.dim },
		NeogitDiffHeader = { fg = p.accent.base, bg = p.background.variant, bold = true },
		NeogitDiffHeaderHighlight = { fg = a.info, bg = p.background.variant, bold = true },
		NeogitHunkHeaderCursor = { link = "NeogitHunkHeaderHighlight" },

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
