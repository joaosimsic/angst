---@meta

---@class ThemePalette
---@field palette ThemePaletteBase
---@field ui ThemePaletteUi
---@field syntax ThemePaletteSyntax
---@field diagnostic ThemePaletteDiagnostic
---@field ansi ThemePaletteAnsi

---@class ThemePaletteBase
---@field black string
---@field base string
---@field dim string
---@field subtle string
---@field accent string
---@field surface string
---@field overlay string

---@class ThemePaletteUi
---@field fg string
---@field bg string
---@field bright string
---@field muted string
---@field comment string
---@field surface string
---@field subtle string
---@field accent string
---@field border string
---@field selectionBg string
---@field selectionFg string
---@field overlay string
---@field prompt string

---@class ThemePaletteSyntax
---@field comment string
---@field keyword string
---@field string string
---@field ["function"] string
---@field variable string
---@field constant string
---@field operator string
---@field type string
---@field number string
---@field punctuation string

---@class ThemePaletteDiagnostic
---@field error string
---@field warning string
---@field info string
---@field hint string
---@field success string

---@class ThemePaletteAnsi
---@field normal ThemePaletteAnsiColors
---@field bright ThemePaletteAnsiColors

---@class ThemePaletteAnsiColors
---@field black string
---@field red string
---@field green string
---@field yellow string
---@field blue string
---@field magenta string
---@field cyan string
---@field white string

---@class ThemeColors
---@field editor ThemeEditorColors
---@field syntax ThemeSyntaxColors
---@field diagnostic ThemeDiagnosticColors
---@field diff ThemeDiffColors
---@field status ThemeStatusColors
---@field mode ThemeModeColors
---@field git ThemeGitColors
---@field rainbow string[]
---@field debug ThemeDebugColors

---@class ThemeEditorColors
---@field fg string
---@field bg string
---@field bright string
---@field muted string
---@field dim string
---@field comment string
---@field surface string
---@field subtle string
---@field accent string
---@field border string
---@field selectionBg string
---@field selectionFg string
---@field overlay string
---@field prompt string

---@class ThemeSyntaxColors
---@field comment string
---@field keyword string
---@field string string
---@field ["function"] string
---@field variable string
---@field constant string
---@field property string
---@field operator string
---@field type string
---@field number string
---@field punctuation string
---@field preproc string
---@field special string
---@field label string
---@field tag string

---@class ThemeDiagnosticColors
---@field error string
---@field warn string
---@field info string
---@field hint string
---@field ok string

---@class ThemeDiffColors
---@field add string
---@field change string
---@field delete string
---@field text string

---@class ThemeStatusColors
---@field fg string
---@field bg string
---@field active string
---@field inactive string
---@field muted string
---@field surface string
---@field positionFg string
---@field positionBg string

---@class ThemeModeColors
---@field fg string
---@field normal string
---@field insert string
---@field visual string
---@field select string
---@field replace string
---@field command string
---@field terminal string
---@field fallbackFg string
---@field fallbackBg string

---@class ThemeGitColors
---@field branch string
---@field add string
---@field change string
---@field delete string

---@class ThemeDebugColors
---@field border string
---@field header string
---@field info string
---@field label string
---@field muted string
---@field ok string
---@field tabActiveFg string
---@field tabActiveBg string
---@field tabInactiveFg string
---@field tabInactiveBg string
---@field value string
---@field warn string

---@alias HighlightStyle vim.api.keyset.highlight

---@alias HighlightGroups table<string, HighlightStyle>

---@class HighlightModule
---@field get fun(p: ThemeColors): HighlightGroups

---@alias ThemeColorKey
---| "fg"
---| "bg"
---| "base"
---| "bright"
---| "dim"
---| "subtle"
---| "accent"
---| "surface"
---| "black"
---| "comment"
---| "green"
---| "green_bright"
---| "red"
---| "red_bright"
---| "yellow"
---| "yellow_bright"
---| "blue"
---| "blue_bright"
---| "magenta"
---| "magenta_bright"
---| "cyan"
---| "cyan_bright"

---@alias ThemePaletteKey ThemeColorKey
