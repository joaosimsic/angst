# Theme management

This document describes how themes work in angst today, the implicit contracts
that hold the system together, known gaps, and a detailed roadmap of planned
improvements.

---

## Table of contents

1. [Goals](#goals)
2. [Current architecture](#current-architecture)
3. [Key files](#key-files)
4. [Token contract](#token-contract)
5. [Color formats](#color-formats)
6. [How it works end-to-end](#how-it-works-end-to-end)
7. [Adding a theme today](#adding-a-theme-today)
8. [Adding a templated config today](#adding-a-templated-config-today)
9. [What works well](#what-works-well)
10. [Known limitations](#known-limitations)
11. [Planned improvements](#planned-improvements)
    - [1. Template validation at eval time](#1-template-validation-at-eval-time)
    - [2. Shared theme schema](#2-shared-theme-schema)
    - [3. Reference colorful theme](#3-reference-colorful-theme)
    - [4. Auto-discover themes](#4-auto-discover-themes)
    - [5. Semantic tokens](#5-semantic-tokens)
    - [6. Restrict `_RGB` generation](#6-restrict-_rgb-generation)
    - [7. Home Manager theme option](#7-home-manager-theme-option)
    - [8. Template lint command](#8-template-lint-command)
    - [9. Rendered config inspection](#9-rendered-config-inspection)
    - [10. Expand templated coverage](#10-expand-templated-coverage)
12. [Implementation order](#implementation-order)
13. [Checklist](#checklist)
14. [Non-goals](#non-goals)

---

## Goals

The theme system exists to solve one problem: **keep terminal and shell colors
consistent across tools without duplicating hex values in five places.**

Design constraints:

- **Single source of truth** — each theme is one Nix attrset of color tokens.
- **Host-level selection** — pick a theme per machine in `hosts/<name>/default.nix`.
- **Minimal domain wiring** — domains drop `.template` files in their `config/`
  directory; the domain loader discovers and renders them automatically.
- **Eval-time rendering** — templates are substituted during Home Manager
  evaluation; no runtime templating engine is required on the host.
- **Tool-native formats** — ghostty wants bare hex, starship/nushell want
  `#`-prefixed hex, zellij wants space-separated RGB triplets. The theme layer
  handles conversion where possible.

---

## Current architecture

```
hosts/<hostname>/default.nix
        │
        │  theme = "monochrome"
        ▼
lib/build/mkHome.nix
        │
        │  themesLib.get name  →  theme attrset (+ *_RGB variants)
        ▼
extraSpecialArgs.theme
        │
        ▼
lib/domains/  →  mkDomainModule
        │
        │  mkXdgSymlinks { configDir = ".../config"; inherit theme; }
        ▼
lib/template/render.nix
        │
        │  replace {{TOKEN}} placeholders in *.template files
        ▼
home-manager xdg.configFile  →  rendered text deployed to ~/.config
```

### Data flow summary

| Stage | Input | Output |
|-------|-------|--------|
| Host config | `theme = "monochrome"` | theme name string |
| `themes/default.nix` | theme name | full token attrset with `*_RGB` |
| `mkXdgSymlinks` | `config/` dir + theme | list of xdg config entries |
| `renderTemplate.nix` | template file + tokens | final config string |

The `theme` value is passed as a **special arg** to all Home Manager modules,
including auto-generated domain modules. Custom domain modules can also accept
`theme` in their function head if they need programmatic access to colors.

---

## Key files

| File | Role |
|------|------|
| `themes/default.nix` | Theme registry, `get`/`default`, `hexToRgb`, `withRgb` |
| `themes/schema.nix` | Required and optional token lists |
| `themes/monochrome.nix` | Palette for the monochrome theme (bare hex, no `#`) |
| `themes/catppuccin-mocha.nix` | Reference colorful palette (Catppuccin Mocha) |
| `lib/template/render.nix` | `{{TOKEN}}` string substitution with leftover detection |
| `lib/template/placeholders.nix` | Extract `{{TOKEN}}` placeholders from template text |
| `lib/template/tokens.nix` | Theme tokens + derived colors (`*_BRIGHT`, `SURFACE`, …) |
| `lib/template/default.nix` | Template bundle: `mkTokens`, `renderTemplateFor`, `findTemplates` |
| `lib/checks/themes.nix` | Validate themes and templates (`nix run .#lint-themes`) |
| `lib/checks/desktop.nix` | Parse-check rendered i3/i3status configs (`nix run .#lint-desktop`) |
| `lib/checks/shell.nix` | Parse-check rendered starship/nushell configs (`nix run .#lint-shell`) |
| `lib/checks/theme/rendered.nix` | Assert host theme renders distinct hues per tool |
| `lib/checks/theme/context.nix` | Host theme + alternate theme for override tests |
| `lib/flake/default.nix` | Flake checks, apps, packages, and home config wiring |
| `lib/home/themeModule.nix` | Home Manager `options.theme` enum |
| `lib/domains/xdg.nix` | `mkXdgSymlinks` — recursive template discovery and rendering |
| `lib/domains/default.nix` | Domain scan + module generation (public API) |
| `lib/build/mkHome.nix` | Loads theme from host config, injects into HM |
| `hosts/*/default.nix` | Per-host `theme` field |

### Templated configs (current)

| Domain | Template | Deployed as |
|--------|----------|-------------|
| ghostty | `domains/terminal/ghostty/config/colors.conf.template` | `~/.config/ghostty/colors.conf` |
| zellij | `domains/terminal/zellij/config/config.kdl.template` | `~/.config/zellij/config.kdl` |
| zellij | `domains/terminal/zellij/config/layouts/default.kdl.template` | `~/.config/zellij/layouts/default.kdl` |
| nushell | `domains/shell/nushell/config/colors.nu.template` | `~/.config/nushell/colors.nu` |
| starship | `domains/shell/starship/config/starship.toml.template` | `~/.config/starship/starship.toml` |
| i3 | `domains/wm/i3/config/config.template` (+ fragments) | `~/.config/i3/config` |
| i3status | `domains/bar/i3status/config/config.template` | `~/.config/i3status/config` |
| i3status bar | `domains/bar/i3status/bar.template` | i3 config fragment |

Non-color configs (e.g. `ghostty/config`, `nushell/config.nu`, `nushell/env.nu`)
are deployed as static files and are **not** theme-aware.

---

## Token contract

Themes are flat attrsets with two token layers:

1. **Semantic tokens** — what templates should reference for meaning (`FG`, `ERROR`, …).
2. **Palette tokens** — ANSI slot colors for ghostty's 16-color block only (`RED`, `BLUE`, …).

The **monochrome** theme defines these semantic tokens (bare hex, no `#`):

| Token | Monochrome value | Role |
|-------|------------------|------|
| `FG` | `eeeeee` | Primary foreground / body text |
| `BRIGHT` | `ebebeb` | Emphasis, highlights, active states |
| `MUTED` | `6b6b6b` | Secondary / de-emphasized foreground |
| `BG` | `0a0a0a` | Background, inverse foreground |
| `COMMENT` | `838383` | Comments, metadata, muted text |
| `ERROR` | `9b9b9b` | Errors, destructive (monochrome: gray) |
| `SUCCESS` | `a7a7a7` | Success (monochrome: gray) |
| `WARNING` | `b3b3b3` | Warnings, git status (monochrome: gray) |
| `INFO` | `8f8f8f` | Info, glob patterns (monochrome: gray) |

Palette tokens (`BLACK`, `RED`, `GREEN`, `YELLOW`, `CYAN`, `BLUE`, `MAGENTA`,
`BASE`, `DIM`) are defined separately for ghostty's ANSI palette. In colorful
themes they may differ from semantic roles; in monochrome they alias to the same
grays.

### Derived tokens

`themes/default.nix` automatically adds `*_RGB` variants for every base token
via `withRgb`. Example:

```
FG        = "eeeeee"
FG_RGB    = "238 238 238"
```

These are consumed exclusively by zellij's KDL theme blocks. Templates should
never define `*_RGB` manually in theme files.

### Token usage by tool

**ghostty** (`colors.conf.template`) — uses palette tokens only:
`BLACK`, `BASE`, `DIM`, `RED`, `GREEN`, `YELLOW`, `CYAN`, `BLUE`, `MAGENTA`, `BRIGHT`.

**starship** (`starship.toml.template`) — uses semantic tokens:
`BRIGHT`, `ERROR`, `COMMENT`, `WARNING`, `SUCCESS`, `FG`.

**nushell** (`colors.nu.template`) — uses semantic tokens.

**zellij** (`config.kdl.template`) — uses `*_RGB` variants of semantic tokens:
`BRIGHT`, `BG`, `FG`, `MUTED`, `ERROR`.

**zellij layout** (`layouts/default.kdl.template`) — uses semantic hex with `#`
prefix in zjstatus format strings: `FG`, `BG`, `BRIGHT`.

**i3** (`config/config.template`) and **i3status** (`config/config.template`, `bar.template`) — use semantic tokens. Domains are decoupled by category (`wm`, `bar`, `launcher`, `session`, `terminal`, …): each contributes i3 config lines via `domains.wm._i3.configLines` when enabled, without referencing sibling domains.

---

## Color formats

Templates are responsible for wrapping tokens in the format their tool expects.
The theme layer stores **bare hex** only.

| Tool | Template pattern | Example output |
|------|------------------|----------------|
| ghostty | `#{{TOKEN}}` or bare `{{TOKEN}}` | `palette = 1=#9b9b9b` |
| starship | `#{{TOKEN}}` inside style strings | `style = "bold #ebebeb"` |
| nushell | `"#{{TOKEN}}"` | `header: { fg: "#eeeeee" }` |
| zellij KDL theme | `{{TOKEN_RGB}}` | `base 235 235 235` |
| zjstatus (in layout) | `#{{TOKEN}}` | `#[bg=#eeeeee,fg=#0a0a0a]` |

This split is intentional: a single `hexToRgb` helper covers zellij's needs
without forcing all tools into one format.

---

## How it works end-to-end

1. **Host declares a theme name** in `hosts/personal/default.nix`:
   ```nix
   theme = "monochrome";
   ```

2. **`mkHomeProfile`** resolves it:
   ```nix
   themesLib = import ../themes/default.nix { inherit lib; };
   theme = themesLib.get (hostConfig.theme or themesLib.default);
   ```

3. **`themesLib.get`** looks up the theme, applies `withRgb`, and returns the
   full token attrset. Unknown names throw:
   ```
   error: Unknown theme: foo
   ```

4. **Domain modules** receive `theme` via `extraSpecialArgs`. When a domain is
   enabled, `mkXdgSymlinks` walks `domains/<cat>/<name>/config/` recursively.

5. **Template discovery rules** (in `mkXdgSymlinks`):
   - Scans `domains/<cat>/<name>/config/` when that directory exists (otherwise the domain root).
   - `foo.template` → rendered to `foo` (`.template` suffix stripped).
   - `foo` with a sibling `foo.template` → skipped (template takes precedence).
   - Everything else → deployed as a static `source` file.
   - Domains with `customXdg = true` in `meta.nix` (e.g. i3) manage `xdg.configFile` in `module.nix` instead.

6. **`renderTemplate.nix`** reads the template and replaces every
   `{{TOKEN}}` where `TOKEN` is a key in the theme attrset.

---

## Adding a theme today

1. Copy an existing theme file, e.g. `themes/catppuccin-mocha.nix` → `themes/<name>.nix`.

2. Define all tokens from `themes/schema.nix` — `semanticTokens` plus `paletteTokens`.
   Values are 6-char lowercase hex without `#`. Do not define `*_RGB` manually.

   ```nix
   {
     FG = "cdd6f4";
     BG = "1e1e2e";
     BRIGHT = "bac2de";
     # ... remaining semantic + palette tokens
   }
   ```

3. The theme is auto-discovered from the filename (`<name>.nix` → `"<name>"`).

4. Set it on a host (or override in `home.nix`):
   ```nix
   theme = "<name>";
   ```

5. Validate and build:
   ```bash
   nix run .#lint-themes
   nix flake check
   nix build .#homeConfigurations.joao.activationPackage
   home-manager switch --flake .#joao
   ```

Missing tokens, invalid hex, and unresolved template placeholders fail at eval
time. `nix run .#lint-themes` catches template issues without a full Home Manager
build.

---

## Adding a templated config today

1. Add `domains/<category>/<domain>/config/<file>.template` with `{{TOKEN}}`
   placeholders.

2. If a static `<file>` already exists, either delete it or keep it — the
   loader skips static files when a `.template` sibling exists.

3. Rebuild. No changes to `meta.nix` or domain modules are needed unless the
   file lives outside the domain's `config/` tree.

4. Use only tokens defined in the theme (see [Token contract](#token-contract)).

---

## What works well

- **Central registry** — one place to list themes, one function to resolve them.
- **Automatic discovery** — new templates require zero Nix wiring.
- **Host-level switching** — change one line in `default.nix` to retheme a machine.
- **Fail-fast on unknown theme names** — typos in host config are caught at eval.
- **Dual-format support** — `withRgb` cleanly bridges hex and zellij RGB without
  duplicating values in theme files.
- **Builds cleanly** — the current setup evaluates and deploys without errors.

---

## Known limitations

### 1. Partial tool coverage

Font settings, keybinds, and structural config are static. Only color-bearing
files are templated. New tools with colors require a conscious decision.

### 2. No runtime theme switching

Theme is fixed at Home Manager evaluation time. Changing themes requires a
rebuild and `home-manager switch`, not a live toggle.

---

## Planned improvements

The items below are ordered by priority. Each section describes the problem,
proposed solution, affected files, and acceptance criteria.

---

### 1. Template validation at eval time

**Problem:** Missing or mistyped tokens produce silently broken configs.

**Solution:** After rendering (or before), scan the output for remaining
`{{...}}` patterns. If any remain, throw with a message naming the template
path and the unresolved placeholders.

**Implementation sketch** — extend `lib/renderTemplate.nix`:

```nix
{ lib, templatePath, tokens }:

let
  template = builtins.readFile templatePath;

  rendered = /* existing foldl' replacement logic */;

  # Match any remaining {{TOKEN}} in output
  leftover = builtins.match ".*\\{\\{([A-Z_]+)\\}\\}.*" rendered;
in
if leftover != null then
  builtins.throw ''
    Template ${templatePath} has unresolved placeholders.
    First unmatched token: ${builtins.elemAt leftover 0}
    Available theme keys: ${lib.concatStringsSep ", " (lib.attrNames tokens)}
  ''
else
  rendered
```

Alternatively, extract placeholders from the template first and diff against
theme keys (more precise error messages, catches all missing tokens at once).

**Affected files:**
- `lib/renderTemplate.nix` (primary)
- Optionally `lib/validateTemplate.nix` (if logic grows)

**Acceptance criteria:**
- Adding `{{TYPO}}` to any template causes eval failure with a clear message.
- A theme missing one required token fails at eval, not at runtime in ghostty.
- Existing templates pass validation with the monochrome theme.

**Priority:** High — do this before adding a second theme.

---

### 2. Shared theme schema

**Problem:** No single source of truth for which tokens a theme must define.

**Solution:** Create `themes/schema.nix` exporting the canonical list of required
base tokens (and optionally their descriptions):

```nix
{
  semanticTokens = [
    "FG" "BG" "BRIGHT" "MUTED" "COMMENT"
    "ERROR" "SUCCESS" "WARNING" "INFO"
  ];

  paletteTokens = [
    "BLACK" "RED" "GREEN" "YELLOW" "CYAN" "BLUE" "MAGENTA" "BASE" "DIM"
  ];
}
```

Add a `validateTheme` function in `themes/default.nix`:

```nix
validateTheme = name: theme:
  let
    required = schema.semanticTokens ++ schema.paletteTokens;
    missing = lib.filter (t: !(theme ? ${t})) required;
    invalid = lib.filter (t:
      !builtins.match "[0-9a-fA-F]{6}" theme.${t}
    ) (lib.attrNames theme);
  in
  if missing != [ ] then
    throw "Theme '${name}' missing tokens: ${lib.concatStringsSep ", " missing}"
  else if invalid != [ ] then
    throw "Theme '${name}' has invalid hex for: ${lib.concatStringsSep ", " invalid}"
  else
    theme;
```

Call `validateTheme` inside `get` before `withRgb`.

**Affected files:**
- `themes/schema.nix` (new)
- `themes/default.nix`
- Each `themes/<name>.nix` (must conform)

**Acceptance criteria:**
- Removing a token from `monochrome.nix` causes eval failure naming the token.
- Invalid hex like `"gggggg"` is rejected.
- Schema is the single place to update when adding a new token to templates.

**Priority:** High — pairs naturally with improvement #1.

---

### 3. Reference colorful theme

**Problem:** The monochrome theme masks template assumptions (RED == GREEN == gray).
A colorful theme would immediately expose missing tokens, bad palette slot
mappings, and semantic naming issues.

**Solution:** Add `themes/<name>.nix` with distinct hues. Suggested starting points:

- **catppuccin-mocha** — well-documented palette, widely used, good contrast.
- **gruvbox-dark** — smaller palette, easy to map.
- **angst-default** — a custom palette native to this repo.

When adding a colorful theme, also update `ghostty/colors.conf.template` to use
`BLUE` and `MAGENTA` in palette slots 5 and 13 instead of reusing `RED`/`CYAN`.

**Affected files:**
- `themes/<new-theme>.nix` (new)
- `themes/default.nix` (register)
- `themes/schema.nix` (add `BLUE`, `MAGENTA` to optional or required)
- `domains/terminal/ghostty/config/colors.conf.template` (palette slots)

**Acceptance criteria:**
- `theme = "<new-theme>"` builds and deploys all templated configs (ghostty, zellij, nushell, starship, i3).
- Visual inspection: ghostty, zellij status bar, starship prompt, and nushell
  syntax highlighting show distinct hues where semantics differ (error vs success
  vs comment).
- Template validation (improvement #1) passes for both themes.

**Priority:** Medium — best done after #1 and #2, but before declaring the theme
system "complete."

---

### 4. Auto-discover themes

**Problem:** Manual registration in `themes/default.nix` is friction and a common
source of "theme file exists but isn't selectable."

**Solution:** Scan the `themes/` directory and import every `*.nix` file except
`default.nix` and `schema.nix`:

```nix
themesDir = ./.;
themeFiles = lib.filterAttrs
  (name: type:
    type == "regular"
    && lib.hasSuffix ".nix" name
    && name != "default.nix"
    && name != "schema.nix"
  )
  (builtins.readDir themesDir);

themes = lib.mapAttrs'
  (filename: _:
    let name = lib.removeSuffix ".nix" filename;
    in lib.nameValuePair name (import (themesDir + "/${filename}")))
  themeFiles;
```

Theme name becomes the filename without extension: `monochrome.nix` → `"monochrome"`.

**Affected files:**
- `themes/default.nix`

**Acceptance criteria:**
- Adding `themes/foo.nix` makes `"foo"` available via `themesLib.get "foo"` with
  no edits to `default.nix`.
- `default.nix` and `schema.nix` are never treated as themes.

**Priority:** Medium — low effort, nice quality-of-life.

---

### 5. Semantic tokens

**Problem:** Templates couple meaning to palette slot names. `shape_garbage` uses
`RED`, starship's `error_symbol` uses `RED`, ghostty palette slot 1 uses `RED` —
but in a colorful theme these may need different values (soft red for errors vs
bright red for ANSI red).

**Solution:** Introduce a semantic layer in theme files:

```nix
# themes/catppuccin.nix
{
  # Semantic roles (what templates should reference)
  fg         = "cdd6f4";
  fgMuted    = "6c7086";
  bg         = "1e1e2e";
  accent     = "89b4fa";
  error      = "f38ba8";
  success    = "a6e3a1";
  warning    = "fab387";
  info       = "89dceb";

  # Legacy palette aliases (for ghostty 16-color palette only)
  palette = {
    black   = "45475a";
    red     = "f38ba8";
    green   = "a6e3a1";
    # ...
  };
}
```

Migration path:

1. Add semantic tokens to schema as the **preferred** template vocabulary.
2. Update templates incrementally: `{{RED}}` → `{{error}}` where the meaning is
   "error", keep `{{palette.red}}` or flat palette tokens only in ghostty's
   16-color block.
3. Deprecate direct `RED`/`GREEN`/etc. in non-palette templates.

Alternative lighter approach: keep flat tokens but rename to semantic names
everywhere (`ERROR`, `SUCCESS`, `WARNING`, `INFO`, `MUTED`, `FG`, `BG`,
`ACCENT`). Simpler migration, no nested attrset.

**Affected files:**
- `themes/schema.nix`
- All `themes/*.nix`
- All `*.template` files
- `themes/default.nix` (`withRgb` must only run on hex color values)

**Acceptance criteria:**
- Templates express intent (`error`, `muted`) not ANSI slot names.
- ghostty palette can still map 16 ANSI colors independently of semantic roles.
- Both monochrome and a colorful theme render correctly.

**Priority:** Low–medium — valuable when adding colorful themes; not urgent for
monochrome-only usage.

---

### 6. Restrict `_RGB` generation

**Problem:** `withRgb` blindly converts every non-`_RGB` key. Future theme
metadata would break.

**Solution:** Only derive `_RGB` for keys listed in the schema (or keys matching
a hex pattern):

```nix
withRgb = theme:
  let
    colorKeys = lib.filter
      (k: lib.elem k schema.semanticTokens || lib.elem k schema.paletteTokens)
      (lib.attrNames theme);
  in
  theme // lib.genAttrs
    (map (k: "${k}_RGB") colorKeys)
    (map (k: hexToRgb theme.${k}) colorKeys);
```

Or pattern-based:

```nix
isHexColor = value: builtins.match "[0-9a-fA-F]{6}" value != null;
```

**Affected files:**
- `themes/default.nix`

**Acceptance criteria:**
- Adding `description = "A gray theme"` to a theme file does not create
  `description_RGB`.
- All existing `*_RGB` tokens still generate correctly.

**Priority:** Low — cheap to implement alongside #2.

---

### 7. Home Manager theme option

**Problem:** Theme is only configurable via `hosts/<name>/default.nix`. There is
no way to override it from a Home Manager module or per-user flake output without
editing host config.

**Solution:** Add a top-level Home Manager option:

```nix
# lib/themeModule.nix or core/home.nix
options.theme = lib.mkOption {
  type = lib.types.enum (lib.attrNames themesLib.themes);
  default = themesLib.default;
  description = "Color theme for templated configs.";
};
```

Wire it so domain modules read `config.theme` (with host config as the option
default) instead of only `hostConfig.theme`. Host config remains the default
source; the HM option allows overrides in `hosts/<name>/home.nix`.

**Affected files:**
- `core/home.nix` or new `lib/themeModule.nix`
- `lib/mkHome.nix`
- `hosts/*/home.nix` (optional overrides)

**Acceptance criteria:**
- Host config `theme` still works unchanged.
- Setting `theme = "catppuccin"` in `home.nix` overrides the host default.
- Invalid theme names are rejected by the enum type.

**Priority:** Low — convenience, not correctness.

---

### 8. Template lint command

**Problem:** Validation only runs during a full Home Manager eval, which is slow
for iterative template editing.

**Solution:** Add a flake app or script:

```bash
nix run .#lint-themes
```

That:

1. Collects all `*.template` files under `domains/`.
2. Extracts `{{TOKEN}}` placeholders from each.
3. Checks every registered theme defines all required tokens.
4. Optionally renders each template and checks for leftover placeholders.
5. Prints a summary table.

**Implementation options:**
- Pure Nix flake app (`apps.lint-themes.program`).
- Small script in `scripts/lint-themes.nix` imported by the flake.

**Affected files:**
- `flake.nix` (app output)
- `lib/lintThemes.nix` (new)

**Acceptance criteria:**
- Runs in under a few seconds (no full HM eval).
- Exit code 1 on any validation failure.
- Usable in CI or pre-commit.

**Priority:** Medium — high developer experience value once multiple templates
and themes exist.

---

### 9. Rendered config inspection

**Problem:** Debugging template output requires building Home Manager and
digging through the nix store.

**Solution:** Add a flake app to render and print (or write to `/tmp`) a specific
template with a given theme:

```bash
nix run .#render-template -- ghostty/colors.conf monochrome
# or
nix run .#render-template -- themes/monochrome
```

Implementation: expose `renderTemplate` and `themesLib.get` via flake outputs,
accept template path + theme name, print result to stdout.

**Affected files:**
- `flake.nix`
- `lib/renderTemplate.nix` (no changes, just re-exported)

**Acceptance criteria:**
- Can inspect any template's rendered output without a full HM build.
- Useful for diffing two themes: `diff <(nix run ... mono) <(nix run ... colorful)`.

**Priority:** Low — developer convenience.

---

### 10. Expand templated coverage

**Problem:** Only color configs are templated. As new domains are added, some
may embed colors in non-obvious places.

**Candidates for future templating:**

| Domain / file | Color content | Notes |
|---------------|---------------|-------|
| nvim | highlight groups | Likely needs a different approach (Lua/LSP) |
| tmux | status bar colors | Good candidate if tmux domain is added |
| fzf | `--color` flags | Could be a wrapper script or env var |
| bat | `theme` mapping | bat uses its own themes; may not fit this system |
| delta | git diff colors | Good candidate |

**Guideline:** Add a template when a config file contains hardcoded hex/rgb
values that should track the global theme. Do **not** template structural config.

For tools with native theme support (bat, delta to some extent), prefer
pointing at a generated theme file rather than inlining colors in a larger config.

**Priority:** Ongoing — per-domain decision as angst grows.

---

## Implementation order

Recommended sequence:

```
Phase 1 — Safety (before second theme)
  ├── 1. Template validation at eval time
  └── 2. Shared theme schema

Phase 2 — Prove the abstraction
  ├── 3. Reference colorful theme
  └── Update ghostty palette template for BLUE/MAGENTA

Phase 3 — Developer experience
  ├── 4. Auto-discover themes
  ├── 6. Restrict _RGB generation (bundled with schema work)
  └── 8. Template lint command

Phase 4 — Optional refinements
  ├── 5. Semantic tokens (when colorful themes need it)
  ├── 7. Home Manager theme option
  ├── 9. Rendered config inspection
  └── 10. Expand templated coverage (ongoing)
```

---

## Checklist

Use this section to track roadmap progress and as a runbook when changing themes
or templates.

### Current baseline (shipped)

- [x] Central theme registry (`themes/default.nix`)
- [x] Host-level theme selection (`hosts/*/default.nix`)
- [x] Template renderer (`lib/renderTemplate.nix`)
- [x] Automatic template discovery in domains (`lib/domains.nix`)
- [x] Auto-derived `*_RGB` tokens for zellij
- [x] Monochrome theme (`themes/monochrome.nix`)
- [x] ghostty colors template
- [x] zellij config + layout templates
- [x] nushell colors template
- [x] starship config template
- [x] Full Home Manager eval succeeds with theme rendering

---

### Phase 1 — Safety

Do this before adding a second theme.

#### 1. Template validation at eval time

- [x] Extend `renderTemplate.nix` to detect leftover `{{TOKEN}}` in rendered output
- [x] Error message includes template path and unmatched token name
- [x] Error message lists available theme keys
- [x] (Optional) Extract all placeholders from template upfront and diff against theme keys
- [x] Verify: intentional typo in a template causes eval failure
- [x] Verify: existing templates pass with monochrome theme

#### 2. Shared theme schema

- [x] Create `themes/schema.nix` with `semanticTokens` and `paletteTokens` lists
- [x] Implement `validateTheme` in `themes/default.nix`
- [x] Reject themes with missing required tokens
- [x] Reject themes with invalid hex values (not `[0-9a-fA-F]{6}`)
- [x] Call `validateTheme` inside `themesLib.get`
- [x] Verify: removing a token from `monochrome.nix` fails at eval

---

### Phase 2 — Prove the abstraction

#### 3. Reference colorful theme

- [x] Choose palette (catppuccin-mocha, gruvbox-dark, or custom)
- [x] Create `themes/<name>.nix` with all required tokens
- [x] Register theme (manual or via auto-discovery)
- [x] Update `ghostty/colors.conf.template` — use `BLUE` / `MAGENTA` in palette slots 5 and 13
- [x] Add `BLUE` and `MAGENTA` to schema (`paletteTokens`)
- [x] Set `theme = "<name>"` on a test host and build (via `homeConfigurations.joao-theme-override-test` + `checks.home-theme-override-test`)
- [x] Automated: `checks.theme-semantic-distinct` — host theme semantic roles are distinct hues
- [x] Automated: `checks.theme-rendered` — ghostty palette slots, starship SUCCESS/ERROR, nushell ERROR/INFO, zellij FG/BRIGHT render distinct host-theme hues
- [x] Automated: `checks.lint-shell` — rendered starship.toml and colors.nu parse cleanly (taplo + nu)
- [x] Automated: `checks.lint-desktop` — rendered i3/i3status configs parse cleanly
- [ ] Visual spot-check after `home-manager switch` (optional; automated checks cover parse + hue wiring)
- [x] Template validation passes for both monochrome and new theme

---

### Phase 3 — Developer experience

#### 4. Auto-discover themes

- [x] Scan `themes/` with `builtins.readDir`
- [x] Import every `*.nix` except `default.nix` and `schema.nix`
- [x] Theme name derived from filename (without `.nix`)
- [x] Remove manual `themes = { ... }` attrset
- [x] Verify: new file `themes/foo.nix` is selectable as `"foo"` without editing `default.nix`

#### 6. Restrict `_RGB` generation

- [x] Limit `withRgb` to schema-listed color keys (or hex-pattern match)
- [x] Verify: non-color metadata on a theme does not produce `*_RGB` keys
- [x] Verify: all existing `*_RGB` tokens still generate correctly

#### 8. Template lint command

- [x] Create `lib/lintThemes.nix`
- [x] Collect all `domains/**/*.template` files
- [x] Extract `{{TOKEN}}` placeholders from each template (via `lib/templatePlaceholders.nix`)
- [x] Validate every registered theme against required tokens
- [x] Render each template and check for leftover placeholders
- [x] Add `nix run .#lint-themes` flake app
- [x] Exit code 1 on any failure
- [x] Runs in under a few seconds (no full HM eval)
- [x] (Optional) Wire into CI or pre-commit (`nix flake check` runs `checks.lint-themes`, `checks.lint-desktop`, `checks.lint-shell`, `checks.theme-rendered`, `checks.theme-override`, `checks.theme-semantic-distinct`, and `checks.home-theme-override-test`)

---

### Phase 4 — Optional refinements

#### 5. Semantic tokens

- [x] Decide approach: flat semantic names (`FG`, `ERROR`, …) + separate palette tokens for ghostty
- [x] Add semantic tokens to schema (`semanticTokens` + `paletteTokens`)
- [x] Update theme files with semantic roles
- [x] Migrate templates off palette names where meaning differs (e.g. `{{RED}}` → `{{ERROR}}`)
- [x] Keep palette-specific tokens only in ghostty 16-color block
- [x] Both monochrome and colorful themes render correctly

#### 7. Home Manager theme option

- [x] Add `options.theme` enum to Home Manager module
- [x] Wire `mkHome.nix` to read HM option with host config as default
- [x] Verify: host `default.nix` theme still works unchanged
- [x] Verify: override in `home.nix` takes effect (via `homeConfigurations.joao-theme-override-test` and `checks.theme-override`)
- [x] Verify: invalid theme name rejected by enum type

#### 9. Rendered config inspection

- [x] Add `nix run .#render-template` flake app
- [x] Accept template path + theme name as arguments
- [x] Print rendered output to stdout
- [x] Verify: inspect output without full HM build
- [x] Verify: diff two themes with shell redirection

#### 10. Expand templated coverage

- [x] Audit new domains for hardcoded hex/rgb values (none under `domains/`; colors are template-driven)
- [ ] tmux status bar colors (if domain added)
- [ ] delta git diff colors
- [ ] fzf `--color` flags (wrapper or env)
- [ ] nvim highlights (evaluate Lua-based approach separately)
- [ ] bat / delta native themes (prefer generated theme file over inline tokens)

---

### Runbook: add a new theme

- [ ] Copy an existing theme file as starting point (`themes/<name>.nix`)
- [ ] Define all tokens listed in `themes/schema.nix` (`semanticTokens` + `paletteTokens`)
- [ ] Values are 6-char lowercase hex, no leading `#`
- [ ] Do not define `*_RGB` keys manually — they are derived
- [ ] Register theme (edit `themes/default.nix` or rely on auto-discovery)
- [ ] Set `theme = "<name>"` in target host's `default.nix`
- [ ] Run `nix build .#homeConfigurations.joao.activationPackage`
- [x] Run lint command when available: `nix run .#lint-themes`
- [ ] Switch and visually verify all templated tools (see Phase 2 visual checks)

---

### Runbook: add a new templated config

- [ ] Identify config file with hardcoded colors under `domains/<cat>/<name>/config/`
- [ ] Rename or copy to `<file>.template`
- [ ] Replace hex/rgb literals with `{{TOKEN}}` placeholders
- [ ] Use correct format for the tool (`#{{TOKEN}}`, bare `{{TOKEN}}`, or `{{TOKEN_RGB}}`)
- [ ] Remove or keep static `<file>` — loader skips it when `.template` sibling exists
- [ ] Confirm all placeholders exist in `themes/schema.nix` (add new tokens to schema if needed)
- [ ] Update every existing theme file with any new tokens
- [ ] Build Home Manager config
- [x] Verify rendered file in nix store or via render command
- [ ] Confirm target application loads the config without parse errors

---

### Runbook: change an existing token

- [ ] Identify all templates referencing the token (`rg '\{\{TOKEN\}\}' domains/`)
- [ ] Update value in every theme file that defines the token
- [ ] If renaming the token: update schema, all themes, and all templates
- [ ] Build Home Manager config
- [ ] Visually verify affected tools (ghostty, zellij, nushell, starship)
- [ ] Run lint command when available

---

### Runbook: switch theme on a host

- [ ] Edit `hosts/<hostname>/default.nix` → `theme = "<name>"`
- [ ] Confirm theme exists in registry (or auto-discovery finds it)
- [ ] `nix build .#homeConfigurations.<user>.activationPackage`
- [ ] `home-manager switch --flake .#<user>`
- [ ] Restart or reload affected applications (ghostty, zellij sessions, nushell)
- [ ] Visual spot-check prompt, terminal, and multiplexer

---

## Non-goals

These are explicitly out of scope for the theme system:

- **Runtime theme switching** — angst themes at eval time via Home Manager, not
  live toggling. Tools like `base16-shell` or dark/light auto-switch are a
  separate concern.
- **Replacing tool-native theme formats** — bat, delta, and similar tools with
  rich theme ecosystems should use their own theme files where practical, not
  force everything through `{{TOKEN}}` substitution.
- **GUI / IDE theming** — GTK, Qt, VS Code, etc. are separate domain concerns.
- **Wallpaper / pywal integration** — dynamic extraction of colors from images
  is incompatible with reproducible Nix eval without additional machinery.
- **Per-domain theme overrides** — one theme per host keeps the system simple.
  If needed later, pass `theme // domainOverrides` in custom domain modules.

---

## Quick reference

```bash
# Build home config (validates full eval including templates)
nix build .#homeConfigurations.joao.activationPackage

# Run all theme checks (lint, desktop/shell parse, rendered hues, override, override-test build)
nix flake check

# Switch theme (today)
# Edit hosts/personal/default.nix → theme = "monochrome";
# Or override in hosts/personal/home.nix → theme = "catppuccin-mocha";
# Then rebuild and switch.

# Lint templates
nix run .#lint-themes

# Parse-check rendered desktop/shell configs
nix run .#lint-desktop
nix run .#lint-shell

# Preview a rendered template
nix run .#render-template -- terminal/ghostty/config/colors.conf monochrome
```
