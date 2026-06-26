---@meta

---@alias DoktorDiagnosticSeverity "Error" | "Warning" | "Information" | "Hint"
---@alias DoktorJobKind '"compiler"' | '"linter"'
---@alias DoktorCompilerProfile string

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
---@field namespace? integer

---@class DoktorGroupedFile
---@field path string
---@field diagnostics vim.Diagnostic[]
---@field lines table<integer, DoktorLineData>
---@field sorted_lines DoktorLineData[]

---@class DoktorJobSpec
---@field cmd string[]
---@field cwd string
---@field compiler string
---@field kind DoktorJobKind
---@field filetypes string[]

---@class DoktorGuardState
---@field locked boolean
---@field queued boolean

---@class DoktorWindowConfig
---@field width_ratio number
---@field height_ratio number
---@field border string

---@class DoktorConfig
---@field auto_start boolean
---@field namespace_name string
---@field debounce_ms integer
---@field adapter_overrides table<string, DoktorAdapterOverride>
---@field window DoktorWindowConfig

---@class DoktorAdapterOverride
---@field compiler? DoktorJobOverride
---@field linter? DoktorJobOverride

---@class DoktorJobOverride
---@field cmd? string[]|fun():string[]
---@field compiler? string

---@class DoktorCacheState
---@field items DoktorDiagnosticItem[]
---@field is_scanning boolean
---@field needs_rescan boolean
---@field current_bufnr integer?
---@field current_win_id integer?
---@field workspace_ns integer
---@field row_map table<integer, DoktorDiagnosticItem>
---@field target_extensions table<string, boolean>
---@field config DoktorConfig
