# Doktor — Workspace Diagnostics Engine v2

A complete rewrite replacing the current `lua/frontend/navigation/doktor/` module. The existing code handles only in-buffer LSP diagnostics rendered in a floating tree view. v2 adds workspace-level background compilation/linting, save-driven execution, `errorformat`-based parsing, and dual diagnostic namespaces so other consumers (heirline, quickfix, etc.) can read the results.

---

## 1. Module Map & File Layout

All new code lands under `lua/frontend/navigation/doktor/`. Files marked `DROP` are removed from the current implementation.

```
lua/frontend/navigation/doktor/
├── init.lua              # Loader glue: attaches autocommands, calls setup()
├── config.lua            # NEW  — user-facing setup() API, defaults
├── state.lua             # MODIFY — extend DoktorCacheState
├── types.lua             # MODIFY — add workspace types
│
├── engine/
│   ├── init.lua          # NEW  — orchestrator: reads adapters, dispatches jobs
│   ├── runner.lua        # NEW  — async job runner (vim.system / plenary)
│   ├── parser.lua        # NEW  — errorformat -> quickfix -> vim.Diagnostic
│   └── guard.lua         # NEW  — throttle guard (is_scanning / needs_rescan)
│
├── window/
│   ├── init.lua          # REWRITE — render floating window
│   ├── collector.lua     # REWRITE — collect from both namespaces
│   └── formatter.lua     # REWRITE — tree view builder
│
├── keys.lua              # KEEP   — navigation keymaps (minor updates)
├── logger.lua            # KEEP   — no changes needed
│
├── pipeline.lua          # DROP   — replaced by engine/
└── (state.lua)           # MODIFY — field changes only
```

### Responsibility Breakdown

| Module | Responsibility |
|--------|---------------|
| `config.lua` | Expose `require("doktor").setup(opts)` — adapter overrides, namespace settings, UI options |
| `state.lua` | Singleton state table: `items`, `is_scanning`, `needs_rescan`, `current_bufnr`, `current_win_id` |
| `engine/init.lua` | Accept a `BufWritePost` event, look up adapters for the filetype, hand off to runner |
| `engine/runner.lua` | Spawn `vim.system` or plenary job, capture stdout+stderr, return raw output |
| `engine/parser.lua` | Activate a `compiler` profile, run output through `getqflist()`, produce `vim.Diagnostic[]` |
| `engine/guard.lua` | State machine: `try_acquire()` → run job → `release()` → check `needs_rescan` |
| `window/collector.lua` | `vim.diagnostic.get(nil, { namespace = ... })` — merge Layer A + Layer B results |
| `window/formatter.lua` | Build tree lines from grouped diagnostics (existing logic, updated for new types) |
| `window/init.lua` | Render window, update on `DiagnosticChanged`, keep footer counters |

---

## 2. Adapter Extension

The existing adapter system (`lua/backend/adapters/`) maps filetypes to LSP servers, linters, and formatters. Doktor v2 adds two new engine fields to every adapter.

### New fields on `Adapter`

```lua
-- lua/backend/shared/types.lua (additions)
---@field doktor?         string           -- tool name referenced by Doktor
---@field doktor_cmd?     string[]|fun():string[]  -- CLI invocation
---@field doktor_compiler? string          -- compiler profile for errorformat
```

### Example adapters

```lua
-- javascript.lua (additions)
doktor         = "tsc",
doktor_cmd     = { "npx", "tsc", "--noEmit", "--incremental" },
doktor_compiler = "tsc",

-- rust.lua
doktor         = "cargo",
doktor_cmd     = { "cargo", "check" },
doktor_compiler = "rustc",

-- go.lua
doktor         = "go",
doktor_cmd     = { "go", "vet", "./..." },
doktor_compiler = "go",
```

`AdapterScanner` already provides `by_filetype`, `by_tool`, and `supported_filetypes`. These work with `"doktor"` as the engine name without changes — just call `AdapterScanner:by_filetype("doktor", opts)`.

### What `AdapterTool` needs

`AdapterTool.info()` currently assumes LSP-shaped fields (`lsp_settings`, `lsp_root_dir`, etc.). Add a generic fallback path so tool info for the `"doktor"` engine returns `{ cmd, compiler }` without LSP-scoped fields.

---

## 3. Data Definitions

### Core state (`state.lua`)

```lua
---@class DoktorCacheState
---@field items              DoktorDiagnosticItem[]   -- merged workspace + inline items
---@field is_scanning        boolean                  -- throttle lock
---@field needs_rescan       boolean                  -- debounce queue flag
---@field current_bufnr      integer?                 -- floating window buffer
---@field current_win_id     integer?                 -- floating window handle
---@field workspace_ns       integer                  -- vim diagnostic namespace id for Layer B
```

### Diagnostic types (`types.lua`)

```lua
---@class DoktorDiagnosticItem
---@field filename   string                        -- project-relative path
---@field lnum       integer                       -- 0-indexed line
---@field col        integer                       -- 0-indexed column
---@field message    string
---@field severity   DoktorDiagnosticSeverity
---@field source?    string                        -- "tsc", "cargo check", etc.
---@field namespace? integer                       -- which layer produced this

---@class DoktorGroupedFile
---@field path         string                      -- relative file path
---@field diagnostics  vim.Diagnostic[]            -- raw diagnostic objects
---@field lines        table<integer, DoktorLineData>
---@field sorted_lines DoktorLineData[]
```

### Runner job spec

```lua
---@class DoktorJobSpec
---@field cmd      string[]             -- { "npx", "tsc", "--noEmit" }
---@field cwd      string              -- project root
---@field compiler string              -- errorformat profile name ("tsc", "rustc", etc.)
---@field filetypes string[]           -- filetypes this job covers
```

### Config surface (`config.lua`)

```lua
---@class DoktorConfig
---@field auto_start      boolean     -- run on BufWritePost by default
---@field namespace_name  string      -- vim diagnostic namespace name for workspace diags
---@field debounce_ms     integer     -- minimum interval between scans (ms)
---@field adapter_overrides table<string, DoktorJobSpec[]>  -- per-filetype overrides
---@field window          DoktorWindowConfig

---@class DoktorWindowConfig
---@field width_ratio    number       -- floating window width (default 0.8)
---@field height_ratio   number       -- floating window height (default 0.6)
---@field border         string       -- "rounded", "single", "double", etc.
```

Default config:

```lua
{
  auto_start      = true,
  namespace_name  = "doktor-workspace",
  debounce_ms     = 200,
  adapter_overrides = {},
  window = {
    width_ratio  = 0.8,
    height_ratio = 0.6,
    border       = "rounded",
  },
}
```

---

## 4. Event Loop & State Machine

```
BufWritePost
    │
    ▼
┌─────────────────┐
│  engine/guard    │
│  try_acquire()   │
└───────┬─────────┘
        │
   is_scanning=true? ──yes──► set needs_rescan=true, return
        │
        no
        │
        ▼
┌─────────────────┐     ┌─────────────────┐
│  engine/init     │────▶│  engine/runner   │
│  resolve job(s)  │     │  spawn process   │
└─────────────────┘     └───────┬─────────┘
                                │
                         capture stdout+stderr
                                │
                                ▼
                        ┌─────────────────┐
                        │  engine/parser   │
                        │  errorformat→Dx  │
                        └───────┬─────────┘
                                │
                                ▼
                        ┌─────────────────┐
                        │  vim.diagnostic  │
                        │  set(namespace)  │  ◄── Layer B: workspace diagnostics
                        └───────┬─────────┘
                                │
                        DiagnosticChanged fires
                                │
                                ▼
                        ┌─────────────────┐
                        │  window/init     │
                        │  update_buffer   │
                        └───────┬─────────┘
                                │
                                ▼
                        ┌─────────────────┐
                        │  engine/guard    │
                        │  release()       │
                        └───────┬─────────┘
                                │
                        needs_rescan=true?
                                │
                           yes──┴──► restart from top
                           no ──► idle
```

### Guard state machine (`engine/guard.lua`)

```lua
---@class DoktorGuard
---@field locked   boolean
---@field queued   boolean

---@return boolean  # true if the caller should proceed with the scan
function Guard:try_acquire()
  if self.locked then
    self.queued = true
    return false
  end
  self.locked = true
  self.queued = false
  return true
end

function Guard:release()
  self.locked = false
  if self.queued then
    self.queued = false
    self:try_acquire()
    -- trigger scan
  end
end
```

---

## 5. Dual Diagnostic Namespaces

Neovim's `vim.diagnostic.set()` targets a namespace. Doktor uses two so consumers can distinguish source.

| Layer | Namespace | Feed | Cadence |
|-------|-----------|------|---------|
| **A** — Live | `vim.diagnostic.get_namespace(nil)` (default) | LSP `textDocument/publishDiagnostics`, `nvim-lint` | On keystroke / buffer change |
| **B** — Workspace | `vim.api.nvim_create_namespace("doktor-workspace")` | `engine/parser` output | On `BufWritePost` |

### Namespace reset on each scan

Before writing new Layer B diagnostics, call:

```lua
vim.diagnostic.set(namespace, buf, {})  -- clear old results
```

This guarantees stale markers (e.g., a fixed type error in a closed file) are purged.

### Reading from other consumers

```lua
-- heirline, statusline, telescope, etc.
local ws_diags = vim.diagnostic.get(nil, { namespace = doktor_ns })
local live_diags = vim.diagnostic.get(nil)  -- default namespace
local all_diags = vim.diagnostic.get()      -- all namespaces
```

No custom API needed — standard `vim.diagnostic` functions work.

---

## 6. errorformat Pipeline (`engine/parser.lua`)

### Flow

```
raw stdout/stderr
    │
    ▼
set compiler profile → vim.cmd("compiler " .. job.compiler)
    │
    ▼
call setqflist([], "a", { lines = raw_output, efm = &errorformat })
    │
    ▼
getqflist() → quickfix items list
    │
    ▼
vim.diagnostic.fromqflist({ namespace = workspace_ns })
    │
    ▼
Layer B diagnostics populated
```

### Key decisions

1. **Compiler profile lookup.** Use Neovim's built-in `$VIMRUNTIME/compiler/*.vim` profiles. For profiles not shipped by default, ship minimal profiles in `lua/frontend/navigation/doktor/compiler/` (e.g., `tsc.vim`, `rustc.vim`).

2. **Temporary buffer approach.** `setqflist()` with `lines` requires a buffer context. Open a hidden scratch buffer, set `&errorformat` and `&makeprg`, run `cexpr`, then discard the buffer.

3. **Path resolution.** `getqflist()` items contain `bufnr` but workspace diagnostics target closed files. Use the `filename` field from quickfix items as the canonical key, resolve with `vim.fn.fnamemodify(filename, ":p")`.

### edge case: missing compiler profile

If `vim.cmd("compiler " .. name)` fails (no such profile), fall back to `[^:]\+: line [0-9]\+:` — a catchall `errorformat` that handles basic `file:line:message` patterns.

---

## 7. Configuration Surface

### `require("doktor").setup(opts)`

Users call this in `init.lua`. It:

1. Merges `opts` with defaults
2. Creates the workspace diagnostic namespace
3. Registers `BufWritePost` autocmd (if `auto_start` is true)
4. Stores config in `state.lua`

### Adapter overrides

Users can override tool mappings without editing adapter files:

```lua
require("doktor").setup({
  adapter_overrides = {
    typescript = {
      cmd = { "npx", "tsc", "--noEmit", "--project", "tsconfig.ci.json" },
      compiler = "tsc",
    },
    -- add a tool for a filetype with no adapter
    markdown = {
      cmd = { "markdownlint", "**/*.md" },
      compiler = "markdownlint",  -- custom compiler profile
    },
  },
})
```

Overrides take precedence over adapter values. This lets users customize without forking adapter files.

---

## 8. Implementation Phases

### Phase 1 — Foundation (target: modules compile + test harness)
- [ ] Create `lua/frontend/navigation/doktor/engine/` directory
- [ ] Implement `guard.lua` with tests
- [ ] Implement `runner.lua` — wrap `vim.system()` with timeout support
- [ ] Add `doktor`, `doktor_cmd`, `doktor_compiler` fields to each adapter file
- [ ] Extend `AdapterTool.lua` with generic tool info path (non-LSP engines)
- [ ] Verify `AdapterScanner:by_filetype("doktor")` returns correct mappings

### Phase 2 — Parser (target: quickfix → diagnostic pipeline works)
- [ ] Implement `engine/parser.lua`
- [ ] Create `compiler/` profiles for tsc, rustc, go, php
- [ ] Test: feed known compiler output, verify `vim.Diagnostic[]` is correct
- [ ] Test: feed malformed output, verify graceful degradation

### Phase 3 — Engine Orchestrator (target: end-to-end save → diag cycle)
- [ ] Implement `engine/init.lua` — resolve jobs from adapter, dispatch via runner
- [ ] Wire `BufWritePost` → `guard:try_acquire()` → `engine` → `parser` → `vim.diagnostic.set(ns)`
- [ ] Implement namespace reset on each scan
- [ ] Test: save a file, verify workspace diags appear in `vim.diagnostic.get(nil, { namespace = ns })`

### Phase 4 — UI (target: floating window shows workspace results)
- [ ] Rewrite `window/collector.lua` to merge namespaces
- [ ] Rewrite `window/init.lua` — use new collector, update on `DiagnosticChanged`
- [ ] Update `formatter.lua` if needed for new item shapes
- [ ] Add `config.lua` with `setup()` API
- [ ] Delete `pipeline.lua`, update `init.lua` wiring

### Phase 5 — Polish (target: production-ready)
- [ ] Add `needs_rescan` dequeue loop in `guard:release()`
- [ ] Add timeout handling for hanged processes
- [ ] Add per-project `.doktor.lua` config file support
- [ ] Add debounce via `debounce_ms` config
- [ ] Write docs / update this spec

---

## 9. Edge Cases & Error Handling

| Case | Behavior |
|------|----------|
| **Tool binary missing** | `AdapterScanner` already filters; if none found, skip filetype silently |
| **Compiler profile missing** | Fall back to `[^:]+: line [0-9]+:` catchall errorformat |
| **Process timeout (60s)** | `runner.lua` kills process, logs warning, leaves existing diagnostics untouched |
| **Process non-zero exit** | Still parse stderr — compilers write errors to stderr and return non-zero |
| **Empty output** | Clear Layer B namespace (no errors = clean state) |
| **Multiple saves during scan** | `needs_rescan = true`; scan runs again immediately after current job finishes |
| **No adapters for filetype** | Skip — don't spawn a job for unsupported filetypes |
| **Temporary/unnamed buffers** | Skip (`buftype ~= ""` or `bufname == ""`) |
| **Large output (>10MB)** | Truncate to 10MB before parsing, log warning |
| **Symlink / out-of-tree paths** | `vim.fn.fnamemodify(..., ":p")` to resolve; if not under cwd, use absolute path |
| **Encoding errors in output** | Force `vim.system` to use `text` mode; replace invalid UTF-8 sequences |

---

## 10. Integration Points

### Heirline / statusline

Heirline already reads diagnostics from `vim.diagnostic` in `components/diagnostic.lua`. With the workspace namespace populated, it will automatically pick up Layer B diagnostics — no changes needed there unless heirline wants to display separate workspace counts.

### Telescope

A telescope extension can source from `vim.diagnostic.get(nil, { namespace = doktor_ns })` to show only workspace errors in a fuzzy picker.

### Quickfix list

```lua
-- command to populate quickfix from workspace diags
vim.fn.setqflist({}, "r", {
  items = vim.diagnostic.toqflist({ namespace = doktor_ns }),
  title = "Doktor Workspace",
})
```

### Keymaps (existing `keys.lua`)

Keep existing keymaps (`<CR>` to jump, `q` to close, `J`/`K` to scroll). No structural changes needed — row_map still maps line numbers to file:lnum:col triples.
