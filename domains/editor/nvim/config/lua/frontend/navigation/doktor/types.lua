---@meta

---@alias DoktorDiagnosticSeverity "Error" | "Warning" | "Information" | "Hint"

---@alias Diagnostics vim.Diagnostic[]

---@class DoktorLineData
---@field lnum integer
---@field col integer
---@field diags vim.Diagnostic[]

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
---@field row_map table<integer, DoktorDiagnosticItem>

---@class DoktorGroupedFile
---@field path string
---@field diagnostics vim.Diagnostic[]
---@field lines table<integer, DoktorLineData>
---@field sorted_lines DoktorLineData[]
