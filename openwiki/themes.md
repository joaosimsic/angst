# Themes

angst has a **compact color-theme system** that powers consistent theming across 15+ applications. Themes are validated at build time and provide color tokens via a simple Nix interface.

## Compact Token Format (v2)

The theme schema (`/themes/schema.nix`) defines only 13 tokens total:

### Palette (9 values)

Four color roles, each with `base` and `variant`, plus a standalone `dim`:

| Token | Role |
|-------|------|
| `palette.background.base` | Main UI background |
| `palette.background.variant` | Darkest background (panels, surfaces) |
| `palette.surface.base` | Surface/accent blue |
| `palette.surface.variant` | Surface accent green |
| `palette.foreground.base` | Main text / foreground accent |
| `palette.foreground.variant` | Bright text / highlighted foreground |
| `palette.accent.base` | Primary accent (yellow/orange) |
| `palette.accent.variant` | Secondary accent (magenta) |
| `palette.dim` | Muted / dim / comment / error-red |

### ANSI (4 values)

Semantic diagnostic colors:

| Token | Role |
|-------|------|
| `ansi.error` | Error / danger |
| `ansi.warn` | Warning |
| `ansi.info` | Information |
| `ansi.success` | Success / confirmation |

## Available Themes

All 8 themes are defined in `/themes/*.nix`:

| Theme | Style | Background | Accent |
|-------|-------|------------|--------|
| `monochrome` **(default)** | Pure grayscale | `#0a0a0a` | `#b3b3b3` |
| `catppuccin-mocha` | Rich purples/blues | `#1e1e2e` | `#f9e2af` |
| `github` | GitHub dark | `#010409` | `#ff7b72` |
| `gotham` | Dark teal/blue-green | `#0c1014` | `#c23127` |
| `kanagawa` | Warm earthy hues | `#181616` | `#c4b28a` |
| `lotus` | Light/warm lotus | `#f2ecbc` | `#c84053` |
| `miasma` | Earthy/desert tones | `#222222` | `#b36d43` |
| `noctis` | Dark teal/blue | `#03191b` | `#e4b781` |

Each theme file exports a compact attrset matching the schema:

```nix
{
  palette = {
    background = { base = "#222222"; variant = "#000000"; };
    surface    = { base = "#78824b"; variant = "#5f875f"; };
    foreground = { base = "#c9a554"; variant = "#d7c483"; };
    accent     = { base = "#b36d43"; variant = "#bb7744"; };
    dim        = "#685742";
  };
  ansi = {
    error   = "#ff3333";
    warn    = "#ffaa00";
    info    = "#33b5e5";
    success = "#00c851";
  };
}
```

## Theme Library

`/themes/default.nix` is the library entry point. It provides:

### `themesLib.get`

The main access function:

```nix
themesLib.get = name:
  withRgb (validateTheme name (normalizeTheme themes.${name}))
```

Processing chain:
1. **`normalizeTheme`** — Strips `#` prefix from all hex values
2. **`validateTheme`** — Checks every required token exists and is a valid 6-digit hex; fails at build time if invalid
3. **`withRgb`** — Generates `_RGB` suffixed attributes (e.g., `palette_background_base_RGB`) with space-separated decimal RGB values for applications that need them

### `themesLib.themes`

The raw attrset of all imported theme files (keyed by filename without `.nix`).

### `themesLib.default`

The default theme name: `"monochrome"`.

## How Domains Consume Themes

1. **Theme module** (`/lib/home/themeModule.nix`): Defines a `theme` option as an enum of available theme names, defaulting to the host's configured theme.

2. **Domain module** (`/lib/domains/module.nix`): When rendering a domain's config, calls:
   ```nix
   render { inherit themesLib; themeName = config.theme; ... }
   ```

3. **Domain renderer** (e.g., `/domains/terminal/ghostty/render.nix`):
   ```nix
   { themesLib, themeName, ... }:
   let
     t = themesLib.get themeName;
     p = t.palette;
   in
   [{
     path = "domains/terminal/ghostty/config/colors.conf";
     text = ''
       background = ${p.background.base}
       foreground = ${p.foreground.variant}
       palette = 0=#${p.background.variant}
       palette = 1=#${p.dim}
       ...
     '';
   }]
   ```

4. **Flake outputs** (`/lib/flake/default.nix`): Provides `renderDomainOutputsFor`, `renderDomainOutputFor`, and `renderDomainOutputPathsFor` that aggregate all domain renders with injected theme and host context.

## Validation & Checks

The theme system has robust validation:

| Check | What it validates |
|-------|-------------------|
| **lint-themes** | All themes load, all required tokens present, values are valid hex |
| **lint-desktop** | i3 + i3status configs render and parse for every theme |
| **lint-shell** | starship + nushell configs render and parse for every theme |
| **theme-rendered** | Rendered output contains expected theme tokens for the host theme |
| **theme-override** | Changing `theme` option propagates into rendered configs |
| **theme-semantic-distinct** | All ANSI semantic colors are distinct (error, warn, info, success) |
| **home-theme-override-test** | Full home-manager activation with an overridden theme |

The assertion library (`/lib/checks/theme/assertions.nix`) provides `require`, `requireDistinct`, and `requireInfix` helpers. Many domain render files embed inline checks.

## Source Map

| File | Role |
|------|------|
| `/themes/schema.nix` | Compact token schema (13 tokens) |
| `/themes/default.nix` | Theme library: import, normalize, validate, RGB |
| `/themes/catppuccin-mocha.nix` | Catppuccin Mocha theme |
| `/themes/github.nix` | GitHub dark theme |
| `/themes/gotham.nix` | Gotham dark teal theme |
| `/themes/kanagawa.nix` | Kanagawa theme |
| `/themes/lotus.nix` | Lotus light theme |
| `/themes/miasma.nix` | Miasma (earthy/desert) theme |
| `/themes/monochrome.nix` | Default grayscale theme |
| `/themes/noctis.nix` | Noctis (teal/blue) theme |
| `/lib/home/themeModule.nix` | `theme` option definition for home-manager |
| `/lib/checks/theme/` | Theme validation checks |
| `/lib/checks/theme/assertions.nix` | Check helper functions |

## Changing or Adding a Theme

1. Create a new theme file in `/themes/<name>.nix` following the compact schema
2. It will be auto-discovered by `/themes/default.nix`
3. Run `nix run .#lint-themes` to validate
4. Run `nix run .#lint-desktop` and `nix run .#lint-shell` to test renders
5. Set the theme in a host's `default.nix` via `theme = "your-theme-name";`

## Change Guidance

### Modifying theme system internals
- **`/themes/schema.nix`** — Defines the required token structure. Adding a new token here requires updating all 8 theme files (`/themes/*.nix`) and potentially every `render.nix` that consumes them.
- **`/themes/default.nix`** — Theme library with normalization, validation, and RGB conversion. Changes here affect all theme consumers and may break the existing 8 themes.
  - `normalizeTheme` strips `#` prefixes; consumers receive bare hex values and must add `#` themselves.
  - `withRgb` generates `_RGB` suffixed space-separated decimal variants recursively for all leaf values.
- **`/lib/home/themeModule.nix`** — The `theme` option definition. The option type is `enum` constrained to `lib.attrNames themesLib.themes`. Adding a theme updates this automatically.

### Modifying theme validation
- **`/lib/checks/theme/assertions.nix`** — Provides `require`, `requireDistinct`, `requireInfix` helpers used by many domain `render.nix` files for inline checks. Token paths use dot-separated notation (e.g., `"palette.dim"`, `"ansi.error"`).
- **`/lib/checks/theme/semanticDistinct.nix`** — Ensures `ansi.error`, `ansi.success`, `ansi.warn`, `ansi.info` are all distinct.
- **`/lib/checks/theme/rendered.nix`** — Verifies rendered domain configs contain expected theme tokens. Update when adding domains or changing render output paths.
- **`/lib/checks/theme/override.nix`** — Tests theme override propagation. Works by picking an alternate theme (first alphabetically different from the host's theme) and verifying the rendered output changes.

### When adding a new domain that consumes themes
1. Create `render.nix` that uses `themesLib.get themeName` to access theme tokens
2. Use `t.palette.*` and `t.ansi.*` paths for all color references
3. Optionally add `checks` in the render output list for built-in validation
4. The domain's rendered output is automatically included in `lint-desktop`/`lint-shell` if the domain has a `render.nix`
5. Run `nix run .#lint-themes` to verify

### Important constraints
- All 8 themes must always define the same tokens. Adding a token to the schema breaks all themes until they're updated.
- There are no legacy uppercase aliases (`FG`, `BG`, etc.) — consumers use full paths like `t.palette.background.base`.
- `_RGB` variants are generated for every leaf string color value. Applications that consume these (i3) expect space-separated decimal `R G B` format.
