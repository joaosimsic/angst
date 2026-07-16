# Git Diff & Conflict Resolution In-Buffer Options

Replace lazygit's separate TUI with native Neovim buffer-based git workflows.

---

- [Git Diff & Conflict Resolution In-Buffer Options](#git-diff--conflict-resolution-in-buffer-options)
  - [Quick Comparison](#quick-comparison)
  - [Option 1: vim-fugitive (Foundation)](#option-1-vim-fugitive-foundation)
    - [Key Commands](#key-commands)
    - [Conflict Resolution Walkthrough](#conflict-resolution-walkthrough)
    - [Keymaps](#keymaps)
    - [Plugin Spec](#plugin-spec)
    - [Pros](#pros)
    - [Cons](#cons)
  - [Option 2: diffview.nvim (Diff Browser)](#option-2-diffviewnvim-diff-browser)
    - [Key Commands](#key-commands-1)
    - [Plugin Spec](#plugin-spec-1)
    - [Keymaps](#keymaps-1)
    - [Pros](#pros-1)
    - [Cons](#cons-1)
  - [Option 3: Neogit (Magit-style Hub)](#option-3-neogit-magit-style-hub)
    - [Key Commands](#key-commands-2)
    - [Plugin Spec](#plugin-spec-2)
    - [Keymaps](#keymaps-2)
    - [Pros](#pros-2)
    - [Cons](#cons-2)
  - [Option 4: gitsigns.nvim (Inline Decorations)](#option-4-gitsignsnvim-inline-decorations)
    - [Key Commands](#key-commands-3)
    - [Plugin Spec](#plugin-spec-3)
    - [Keymaps](#keymaps-3)
    - [Pros](#pros-3)
    - [Cons](#cons-3)
  - [Option 5: Built-in Neovim + Telescope Git Pickers](#option-5-built-in-neovim--telescope-git-pickers)
    - [Key Commands](#key-commands-4)
    - [Pros](#pros-4)
    - [Cons](#cons-4)
  - [Recommended Implementation](#recommended-implementation)
    - [Phase 1 — Fugitive (mandatory)](#phase-1--fugitive-mandatory)
    - [Phase 2 — Diffview (recommended)](#phase-2--diffview-recommended)
    - [Phase 3 — Gitsigns (optional polish)](#phase-3--gitsigns-optional-polish)
    - [Phase 4 — Remove / reduce lazygit](#phase-4--remove--reduce-lazygit)
  - [Keymap Conflict Audit](#keymap-conflict-audit)
    - [Currently used `<leader>` prefixes](#currently-used-leader-prefixes)
    - [Proposed `<leader>g*` namespace](#proposed-leaderg-namespace)
  - [Migration from Lazygit](#migration-from-lazygit)
    - [What you lose](#what-you-lose)
    - [What you gain](#what-you-gain)

---

## Quick Comparison

| Capability              | fugitive | diffview | neogit | gitsigns | builtin+telescope |
|-------------------------|----------|----------|--------|----------|-------------------|
| In-buffer diffs         | ✅       | ✅       | ✅     | ✅ (hunk)| ⚠️ (diffthis)    |
| 3-way merge conflicts   | ✅       | ❌       | ⚠️     | ❌       | ❌                |
| Stage/unstage           | ✅       | ❌       | ✅     | ✅ (hunk)| ❌                |
| Commit                  | ✅       | ❌       | ✅     | ❌       | ❌                |
| Blame                   | ✅       | ❌       | ✅     | ✅       | ⚠️ (blame.vim)   |
| Log/browse history      | ✅       | ✅       | ✅     | ❌       | ✅ (telescope)    |
| Push/pull/fetch         | ✅       | ❌       | ✅     | ❌       | ❌                |
| GitHub links            | ✅       | ❌       | ❌     | ❌       | ❌                |
| Inline change signs     | ❌       | ❌       | ❌     | ✅       | ❌                |
| Hunk preview popup      | ❌       | ❌       | ❌     | ✅       | ❌                |
| Visual diff tree        | ❌       | ✅       | ✅     | ❌       | ❌                |
| Separate TUI window     | ❌       | ❌       | ❌     | ❌       | ❌                |

---

## Option 1: vim-fugitive (Foundation)

**Maintainer:** tpope  
**Repo:** https://github.com/tpope/vim-fugitive  
**Type:** Comprehensive Git wrapper

No graphical UI. Everything happens in normal Neovim buffers. You run `:Git` or `:Gstatus` and get a buffer that behaves like a normal file.

### Key Commands

| Command | Action |
|---------|--------|
| `:G` | Run any `git` command, output in a buffer |
| `:Gstatus` | `git status` buffer — press `-` to stage/unstage, `cc` to commit, `dd` to diff |
| `:Gvdiffsplit` | Open vertical 3-way diff for merge conflicts (ours / ancestor / theirs) |
| `:Gdiffsplit` | Same but horizontal |
| `:Gdiffsplit <ref>` | Diff current file against `<ref>` |
| `:Gvdiffsplit!` | Reopen with different base |
| `:Gwrite` | Stage current file (or write merge result) |
| `:Gread` | Revert current file (or read a different revision) |
| `:G blame` | Interactive blame with inline annotations |
| `:G log` | Git log in a buffer |
| `:G commit` | Commit with `$EDITOR` (already Neovim) |
| `:G push` / `:G pull` / `:G fetch` | Remote operations |
| `:G browse` | Open current file on GitHub |
| `:G diff` | `git diff` output in a buffer |
| `:[range]G delete` | Delete lines from git (`git rm` semantics) |
| `:G move` | Git-aware rename |
| `:G grep` | Git grep in quickfix |
| `:0Gclog` | Git log for current file in quickfix |

### Conflict Resolution Walkthrough

When you have a merge conflict:

1. Open the conflicted file
2. Run `:Gvdiffsplit` — opens 3 vertical splits:
   - **Left:** Ours (your current branch)
   - **Middle:** Merged file (with conflict markers)
   - **Right:** Theirs (the branch being merged)
3. Navigate between conflict regions with `[c` and `]c` (native Neovim diff navigation)
4. In the middle buffer, resolve the conflict
5. Use `:diffget //2` (get from left/ours) or `:diffget //3` (get from right/theirs) per hunk
6. Save the middle buffer
7. Run `:Gwrite` to stage the resolved file
8. Repeat for all conflicted files

Alternative: after `:Gvdiffsplit`, you can edit the middle buffer directly and use `:Gwrite` when done. Fugitive automatically detects the conflict state.

### Keymaps

For `~/.config/nvim/lua/config/keymaps/editor/fugitive.lua`:

```lua
return {
  {
    "<leader>gs",
    "<cmd>G<CR>",
    desc = "Git status",
    mode = "n",
  },
  {
    "<leader>gd",
    ":Gvdiffsplit<CR>",
    desc = "Git diff (vertical)",
    mode = "n",
  },
  {
    "<leader>gb",
    "<cmd>G blame<CR>",
    desc = "Git blame",
    mode = "n",
  },
  {
    "<leader>gc",
    "<cmd>G commit<CR>",
    desc = "Git commit",
    mode = "n",
  },
  {
    "<leader>gp",
    "<cmd>G push<CR>",
    desc = "Git push",
    mode = "n",
  },
  {
    "<leader>gP",
    "<cmd>G pull<CR>",
    desc = "Git pull",
    mode = "n",
  },
  {
    "<leader>gl",
    "<cmd>G log<CR>",
    desc = "Git log",
    mode = "n",
  },
  {
    "<leader>gB",
    "<cmd>G browse<CR>",
    desc = "Git browse (GitHub)",
    mode = "n",
  },
}
```

### Plugin Spec

Put at `~/.config/nvim/lua/plugins/editor/fugitive.lua`:

```lua
return {
  "tpope/vim-fugitive",
  cmd = { "G", "Git", "Gstatus", "Gvdiffsplit", "Gdiffsplit", "G blame", "G log", "Gwrite", "Gread", "Gbrowse" },
  keys = require("config.keymaps.editor.fugitive"),
  dependencies = { "tpope/vim-rhubarb" }, -- for :Gbrowse
}
```

### Pros

- Most mature Git integration for Vim/Neovim (10+ years)
- No separate UI paradigm — everything is a normal buffer
- Best-in-class 3-way merge conflict resolution
- Every git operation accessible without leaving the editor
- `:Gbrowse` opens exact line range on GitHub/GitLab
- Works with any terminal, any workflow
- Zero performance overhead when not in use

### Cons

- Text-heavy, no visual diff tree or file explorer
- Requires learning buffer-based workflow (not point-and-click)
- No inline signs (you don't see changed lines without running a command)
- `:Gstatus` buffer has a learning curve for its keybindings
- No hunk staging (you can stage individual changes within a buffer)

---

## Option 2: diffview.nvim (Diff Browser)

**Maintainer:** sindrets  
**Repo:** https://github.com/sindrets/diffview.nvim  
**Type:** Visual diff explorer

Opens a focused panel showing a file tree of changed files alongside side-by-side diffs. Best for reviewing what changed before committing or between branches.

### Key Commands

| Command | Action |
|---------|--------|
| `:DiffviewOpen` | Show working tree changes (staged + unstaged) |
| `:DiffviewOpen HEAD` | Show changes since last commit |
| `:DiffviewOpen HEAD~2..HEAD` | Compare two arbitrary refs |
| `:DiffviewOpen origin/main..HEAD` | Diff against remote branch |
| `:DiffviewFileHistory %` | File history for current file |
| `:DiffviewFileHistory` | Branch log with diff view |
| `:DiffviewClose` | Close diffview |
| `:DiffviewToggleFiles` | Toggle file panel |

Inside diffview:
- Tab / Shift-Tab — cycle through files
- `dq` / `dp` — diffget / diffput (merge conflict resolution only in 3-way mode)
- `]x` / `[x` — next/previous conflict
- `do` — diff obtain (get changes)
- `1`, `2`, `3` — focus left, right, or merge buffer in 3-way view

### Plugin Spec

`~/.config/nvim/lua/plugins/editor/diffview.lua`:

```lua
return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
  keys = require("config.keymaps.editor.diffview"),
  config = function()
    require("diffview").setup({
      enhanced_diff_hl = true,
      file_panel = {
        win_width = 35,
      },
    })
  end,
}
```

### Keymaps

`~/.config/nvim/lua/config/keymaps/editor/diffview.lua`:

```lua
return {
  {
    "<leader>gD",
    "<cmd>DiffviewOpen<CR>",
    desc = "Diff view (working tree)",
    mode = "n",
  },
  {
    "<leader>gh",
    "<cmd>DiffviewFileHistory %<CR>",
    desc = "Diff file history",
    mode = "n",
  },
}
```

### Pros

- Clean, visual diff — both tree overview and side-by-side code
- Good for code review workflows (check changes before commit)
- Works between arbitrary refs, not just working tree
- File history with diff per commit
- Toggle between file tree and diff focus quickly

### Cons

- No commit, push, pull, or other git operations
- No 3-way merge conflict resolution for in-file conflicts (can view but not resolve)
- Separate window/panel — not *fully* buffer-native (uses floating/layout windows)
- Overkill if you only want occasional diffs
- Conflicts with fugitive if both claim `g?` keymaps for their diff buffers

---

## Option 3: Neogit (Magit-style Hub)

**Maintainer:** Neogit team  
**Repo:** https://github.com/NeogitOrg/neogit  
**Type:** Full git interface in buffer (Magit for Neovim)

Opens a comprehensive status buffer showing unstaged/staged sections, with keybindings to perform any git operation. More visual than fugitive but still buffer-native.

### Key Commands

| Command | Action |
|---------|--------|
| `:Neogit` | Open Neogit status view |
| `:Neogit kind=replace` | Replace current buffer with Neogit |
| `:Neogit kind=floating` | Open in floating window |
| `:Neogit kind=tab` | Open in new tab |
| `:Neogit log` | Log view |
| `:Neogit diff` | Diff view |
| `:Neogit pull` | Pull |
| `:Neogit push` | Push |

Inside Neogit status buffer:
- `Tab` / `Shift-Tab` — expand/collapse sections
- `s` — stage (hunk or file)
- `S` — stage all
- `u` — unstage
- `U` — unstage all
- `x` — discard changes
- `c` — commit (`cc` to commit, `ca` to amend)
- `b` — branch operations
- `p` — push
- `F` — pull / fetch
- `1` — diff focused view
- `$` — command history
- `?` — help

### Plugin Spec

`~/.config/nvim/lua/plugins/editor/neogit.lua`:

```lua
return {
  "NeogitOrg/neogit",
  cmd = "Neogit",
  keys = require("config.keymaps.editor.neogit"),
  dependencies = {
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim", -- optional: uses diffview for diff tab
    "nvim-telescope/telescope.nvim", -- optional: for log search
  },
  config = function()
    require("neogit").setup({
      disable_signs = false,
      disable_context_highlighting = false,
      disable_commit_confirmation = true,
      kind = "tab",
      -- graph_style = "unicode",
      integrations = {
        diffview = true,
        telescope = true,
      },
    })
  end,
}
```

### Keymaps

`~/.config/nvim/lua/config/keymaps/editor/neogit.lua`:

```lua
return {
  {
    "<leader>gs",
    "<cmd>Neogit<CR>",
    desc = "Neogit status",
    mode = "n",
  },
  {
    "<leader>gl",
    "<cmd>Neogit log<CR>",
    desc = "Neogit log",
    mode = "n",
  },
}
```

### Pros

- Single interface for everything git — commit, push, pull, log, diff, stash, branch
- Visual section-based layout (staged / unstaged / untracked / recent commits)
- Keyboard-driven but discoverable (`?` shows keybindings)
- Hunk staging — stage individual lines or hunks, not just whole files
- Good visual log graph
- Integrates with diffview.nvim for better diffs

### Cons

- Heavier than fugitive (more code, more moving parts)
- Conflict resolution is weaker — no dedicated 3-way merge workflow
- The status buffer replaces your current buffer/window (or uses a tab/floating window)
- Learning curve: different keybindings than fugitive
- Some operations are slower due to the richer UI
- Overlapping features with diffview can cause confusion

---

## Option 4: gitsigns.nvim (Inline Decorations)

**Maintainer:** lewis6991  
**Repo:** https://github.com/lewis6991/gitsigns.nvim  
**Type:** Inline git decorations + hunk operations

This is NOT a full git workflow tool. It complements fugitive/neogit by showing change signs in the signcolumn and providing per-hunk operations without leaving the buffer.

### Key Commands

| Command | Action |
|---------|--------|
| `:Gitsigns toggle_signs` | Show/hide signs |
| `:Gitsigns toggle_linehl` | Show/hide line highlights |
| `:Gitsigns toggle_deleted` | Show virtual text for deleted lines |
| `:Gitsigns toggle_current_line_blame` | Inline blame on current line |
| `:Gitsigns diffthis` | Open diff against index |
| `:Gitsigns preview_hunk` | Popup showing hunk diff |
| `:Gitsigns stage_hunk` | Stage current hunk |
| `:Gitsigns undo_stage_hunk` | Unstage current hunk |
| `:Gitsigns reset_hunk` | Discard hunk changes |
| `:Gitsigns blame_line` | Full blame for current line |

### Plugin Spec

`~/.config/nvim/lua/plugins/editor/gitsigns.lua`:

```lua
return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("gitsigns").setup({
      signs = {
        add          = { text = "│" },
        change       = { text = "│" },
        delete       = { text = "_" },
        topdelete    = { text = "‾" },
        changedelete = { text = "~" },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, lhs, rhs, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, lhs, rhs, opts)
        end

        -- Navigation
        map("n", "]c", function()
          if vim.wo.diff then return "]c" end
          vim.schedule(function() gs.next_hunk() end)
          return "<Ignore>"
        end, { expr = true })

        map("n", "[c", function()
          if vim.wo.diff then return "[c" end
          vim.schedule(function() gs.prev_hunk() end)
          return "<Ignore>"
        end, { expr = true })

        -- Actions
        map("n", "<leader>hs", gs.stage_hunk, { desc = "Stage hunk" })
        map("n", "<leader>hr", gs.reset_hunk, { desc = "Reset hunk" })
        map("v", "<leader>hs", function() gs.stage_hunk { vim.fn.line("."), vim.fn.line("v") } end, { desc = "Stage hunk (visual)" })
        map("v", "<leader>hr", function() gs.reset_hunk { vim.fn.line("."), vim.fn.line("v") } end, { desc = "Reset hunk (visual)" })
        map("n", "<leader>hS", gs.stage_buffer, { desc = "Stage buffer" })
        map("n", "<leader>hu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
        map("n", "<leader>hp", gs.preview_hunk, { desc = "Preview hunk" })
        map("n", "<leader>hb", function() gs.blame_line { full = true } end, { desc = "Blame line" })
        map("n", "<leader>hd", gs.diffthis, { desc = "Diff this" })
        map("n", "<leader>hD", function() gs.diffthis("~") end, { desc = "Diff this against ~" })
        map("n", "<leader>hB", gs.toggle_current_line_blame, { desc = "Toggle inline blame" })
      end,
    })
  end,
}
```

### Keymaps

Built into `on_attach` above using `<leader>h*` prefix. This is separate from the `<leader>g*` namespace used for fugitive/neogit, so they don't conflict.

### Pros

- See changes inline without running any command
- Hunk staging — stage individual hunks, not whole files
- Preview hunk diff in a popup (no separate window)
- Inline blame on current line
- Virtual text for deleted lines (see what was removed)
- Works alongside fugitive or neogit perfectly
- Zero context switch — never leave your buffer

### Cons

- Does NOT replace status, commit, push, pull, log, etc.
- Just a decoration + hunk tool — needs a companion for full workflow
- Can be noisy if you prefer a clean signcolumn
- Inline blame eats horizontal space

---

## Option 5: Built-in Neovim + Telescope Git Pickers

**Dependencies:** None (beyond telescope, which you already have)  
**Type:** Minimal — no third-party git plugins

### Key Commands

| Command | Action |
|---------|--------|
| `vim.cmd("diffthis")` | Enter diff mode for current buffer |
| `:diffget` | Get (accept) change from other buffer |
| `:diffput` | Put (send) change to other buffer |
| `:diffupdate` | Refresh diff highlighting |
| `:diffoff!` | Exit diff mode |
| `[c` / `]c` | Jump to prev/next change |
| `:Telescope git_status` | Changed files picker |
| `:Telescope git_commits` | Browse all commits |
| `:Telescope git_bcommits` | Commits for current buffer |
| `:Telescope git_branches` | Switch/checkout branches |
| `:Telescope git_stash` | Stash management |

**Telescope git pickers are built-in** (no extra plugin) — they call `git` commands directly.

Diff mode workflow:
1. `:Telescope git_status` to pick a changed file
2. Open the file in a split
3. `:Gedit HEAD:%` (or use fugitive) to get the old version in another split
4. `:diffthis` on both buffers
5. Navigate with `[c` / `]c`
6. Accept changes with `:diffget` / `:diffput`
7. `:diffoff!` to exit

For conflict resolution, use Neovim's built-in `:h merge`:
- Open the conflicted file
- `:diffget //2` — get from "ours" (left)
- `:diffget //3` — get from "theirs" (right)
- This works because Git writes 3 stages to the index during conflicts

### Pros

- Zero dependencies (telescope is already installed)
- Built-in diff mode is well-tested and fast
- Telescope pickers are already in your workflow
- No plugin maintenance burden

### Cons

- No dedicated git status buffer (rely on telescope list)
- No inline signs
- No blame support without `vim-fugitive` or `blame.vim`
- No hunk staging
- No commit/push/pull flow (use raw `:!git commit`)
- Conflict resolution is manual (no 3-way split layout)
- No visual log graph
- Significantly more keystrokes for common operations

---

## Recommended Implementation

### Phase 1 — Fugitive (mandatory)

This covers all core needs: status, commit, push/pull, blame, and most importantly **conflict resolution**.

**Files to create:**

| File | Purpose |
|------|---------|
| `~/.config/nvim/lua/plugins/editor/fugitive.lua` | Plugin spec (see above) |
| `~/.config/nvim/lua/config/keymaps/editor/fugitive.lua` | Keymaps (see above) |

No dependency on lazy.nvim being restarted — fugitive is lazy-loaded on command invocation.

### Phase 2 — Diffview (recommended)

Adds visual diff browsing. Useful for reviewing changes before committing or comparing branches.

**Files to create:**

| File | Purpose |
|------|---------|
| `~/.config/nvim/lua/plugins/editor/diffview.lua` | Plugin spec (see above) |
| `~/.config/nvim/lua/config/keymaps/editor/diffview.lua` | Keymaps (see above) |

### Phase 3 — Gitsigns (optional polish)

Adds inline signs and hunk operations. Use if you want to see changes at a glance without running a command.

**File to create:**

| File | Purpose |
|------|---------|
| `~/.config/nvim/lua/plugins/editor/gitsigns.lua` | Plugin spec with hunk keymaps (see above) |

### Phase 4 — Remove / reduce lazygit

**Option A: Remove entirely**

Delete `~/.config/nvim/lua/plugins/ui/lazygit.lua` and `~/.config/nvim/lua/config/keymaps/ui/lazygit.lua`. The `<leader>lg` binding becomes available for other uses.

**Option B: Keep as backup**

Leave it installed but unbound. You can still run `:LazyGit` manually. Unbind from the keymap file.

**Option C: Move to less convenient key**

Assign to `<leader>Lg` or `<leader>xl` so it's accessible but not your primary tool.

---

## Keymap Conflict Audit

### Currently used `<leader>` prefixes

```
<leader>a    ← harpoon add
<leader>c*   ← LSP/trouble (ca, cl, cs)
<leader>d    ← blackhole delete
<leader>e    ← diagnostics float
<leader>f*   ← format, telescope (ff, fg, fb, fo, fh)
<leader>g*   ← currently only lazygit (lg)

  Proposed: gs, gd, gb, gc, gp, gP, gl, gB, gD, gh

<leader>h*   ← currently unused (available for gitsigns)
<leader>j    ← location list prev
<leader>k    ← location list next
<leader>lg   ← lazygit
<leader>m    ← mininotify history
<leader>p    ← paste from blackhole
<leader>pv   ← netrw
<leader>s    ← substitution
<leader>u    ← undotree
<leader>vpp  ← open nvim config
<leader>x*   ← trouble (xx, xL, xQ)
<leader>y/Y  ← yank to clipboard
```

**No conflicts expected** — `<leader>g*` is currently only used by lazygit (`<leader>lg`). Fugitive uses `gs`, `gd`, `gb`, `gl`, etc. Diffview uses `gD`, `gh`. All are free.

If you keep lazygit, reassign it to something like `<leader>gL` or `<leader>gg` to avoid confusion with fugitive's `gs`/`gl`.

### Proposed `<leader>g*` namespace

```
<leader>g  ← (reserved for git prefix)
  gs  → Git status          (fugitive: :G)
  gd  → Git diff             (fugitive: :Gvdiffsplit)
  gb  → Git blame            (fugitive: :G blame)
  gc  → Git commit           (fugitive: :G commit)
  gp  → Git push             (fugitive: :G push)
  gP  → Git pull             (fugitive: :G pull)
  gl  → Git log              (fugitive: :G log)
  gB  → Git browse           (fugitive: :Gbrowse)
  gD  → Diffview open        (diffview: :DiffviewOpen)
  gh  → File history         (diffview: :DiffviewFileHistory %)
  gL  → Lazygit (if kept)    (lazygit: :LazyGit)
```

For gitsigns, use a separate prefix `h`:

```
<leader>h
  hs  → Stage hunk
  hr  → Reset hunk
  hp  → Preview hunk
  hS  → Stage buffer
  hu  → Undo stage hunk
  hb  → Blame line
  hd  → Diff this
  hD  → Diff this against ~
  hB  → Toggle inline blame
```

---

## Migration from Lazygit

### What you lose

| Lazygit feature | Replacement |
|----------------|-------------|
| Visual commit graph | fugitive `:G log` (text) or diffview `:DiffviewFileHistory` (panel) |
| Side-by-side unstaged/staged tree | fugitive `:Gstatus` buffer sections |
| Auto-refresh on file change | fugitive: manual `:G` or `R` in status buffer |
| Mouse support | No mouse in fugitive buffers (keyboard only) |
| Single-window everything | Multiple buffer/window context switches |
| Interactive rebase UI | fugitive `:G rebase -i` in a buffer (text-based) |
| Stash browsing UI | fugitive `:G stash list` in buffer |
| Visual merge conflict editor | fugitive `:Gvdiffsplit` (3-way split) |

### What you gain

| Pain point solved | How |
|------------------|-----|
| Separate TUI takes focus away | Everything is in Neovim buffers |
| Lazygit keybindings not customizable easily | Fugitive/Neogit keymaps are your own |
| Can't copy/paste between lazygit and editor | Diffs are regular buffers — yank/put works |
| Can't use Neovim motions on diffs | Diffs are editable buffers |
| No LSP/gitsigns integration in lazygit | Signs and diagnostics visible alongside diffs |
| Lazygit doesn't show inline blame | fugitive `:G blame` or gitsigns inline blame |
| Hard to diff arbitrary refs | `:Gvdiffsplit <ref>` or `:DiffviewOpen <ref1>..<ref2>` |
| Lazygit crashes/exits unexpectedly | Fugitive is rock-stable, decades old |
