---@meta

---@class ThemePalette
---@field palette ThemePaletteCompact
---@field ansi ThemePaletteAnsiCompact

---@class ThemePaletteCompact
---@field background ThemePalettePair
---@field surface ThemePalettePair
---@field foreground ThemePalettePair
---@field accent ThemePalettePair
---@field dim string

---@class ThemePalettePair
---@field base string
---@field variant string

---@class ThemePaletteAnsiCompact
---@field error string
---@field warn string
---@field info string
---@field success string

---@alias HighlightStyle vim.api.keyset.highlight

---@alias HighlightGroups table<string, HighlightStyle>

---@class HighlightModule
---@field get fun(): HighlightGroups


