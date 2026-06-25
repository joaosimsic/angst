---@meta

---@alias DoktorDiagnosticSeverity "Error" | "Warning" | "Information" | "Hint"

---@class DoktorDiagnosticItem
---@field filename string
---@field lnum integer
---@field col integer
---@field message string
---@field severity DoktorDiagnosticSeverity
---@field source? string

---@class DoktorCacheState
---@field items DoktorDiagnosticItem[]
---@field target_extensions table<string, boolean>
---@field is_scanning boolean
