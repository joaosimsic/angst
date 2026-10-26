# git.yazi

Vendored from [yazi-rs/plugins](https://github.com/yazi-rs/plugins/tree/main/git.yazi)
(`main.lua`, `types.lua`, MIT-licensed, see upstream for LICENSE).

Shows git file-change status as linemode suffix in the file list. Tracks the
`.git` directory upward from `cwd` (`root()` walks parents until `.git` is
found, worktree-aware) and refreshes via fetcher `retry`.

Requires Yazi >= 26.8.15 (`--- @since 26.8.15`); repo currently pins yazi 26.9.1.

Setup lives in the rendered `init.lua` (`require("git"):setup { order = 1500 }`)
and fetchers in `yazi.toml` (`[[plugin.prepend_fetchers]]`, `*` + `*/`,
`group = "git"`). Signs/colors live in the rendered `theme.toml` `[git]`
section. Re-sync with upstream when bumping yazi.

## Divergence from upstream

- `main.lua` (`setup` → `Linemode:children_add`): the `is_hovered` branch was
  removed so the sign keeps its status color on hover. Upstream returns the
  sign unstyled when hovered, which paints every status in the single hover
  color (untracked vs unstaged indistinguishable). Re-apply this hunk after
  any upstream re-sync.
