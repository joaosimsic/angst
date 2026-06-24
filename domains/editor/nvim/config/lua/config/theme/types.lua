---@meta

---@class ThemePalette
---@field base string
---@field bright string
---@field dim string
---@field surface string
---@field bg string
---@field black string
---@field comment string
---@field green string
---@field green_bright string
---@field red string
---@field red_bright string
---@field yellow string
---@field yellow_bright string
---@field blue string
---@field blue_bright string
---@field magenta string
---@field magenta_bright string
---@field cyan string
---@field cyan_bright string

---@alias HighlightStyle vim.api.keyset.highlight

---@alias HighlightGroups table<string, HighlightStyle>

---@class HighlightModule
---@field get fun(p: ThemePalette): HighlightGroups
