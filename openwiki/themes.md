# Themes

angst has a **strict, layered color-theme system** that powers consistent theming across 15+ applications. Themes are validated at build time and provide color tokens via a simple Nix interface.

## Token Layers

The theme schema (`/themes/schema.nix`) defines 5 color layers with 44 tokens total:

### Palette (7 tokens)
`black`, `base`, `dim`, `subtle`, `accent`, `surface`, `overlay`

Foundational color swatches.

### ANSI (16 tokens)
8 colors × 2 variants (`normal`, `bright`):
`black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`

Terminal emulator ANSI color slots.

### UI (13 tokens)
`fg`, `bg`, `bright`, `muted`, `comment`, `surface`, `subtle`, `accent`, `border`, `selectionBg`, `selectionFg`, `overlay`, `prompt`

Interface element colors used by window managers, bars, launchers, and terminal UIs.

### Syntax (11 tokens)
`comment`, `keyword`, `string`, `function`, `variable`, `constant`, `operator`, `type`, `number`, `property`, `punctuation`

Syntax highlighting colors for editor and code-related tooling.

### Diagnostic (5 tokens)
`error`, `warning`, `info`, `hint`, `success`

LSP and diagnostic feedback colors.

### Legacy Aliases (21 tokens)

For backward compatibility and ergonomic access, 21 uppercase aliases are automatically added:
`FG`, `BG`, `BRIGHT`, `MUTED`, `COMMENT`, `ERROR`, `SUCCESS`, `WARNING`, `INFO`, `BLACK`, `RED`, `GREEN`, `YELLOW`, `CYAN`, `BLUE`, `MAGENTA`, `BASE`, `DIM`, `SUBTLE`, `ACCENT`, `SURFACE`

## Available Themes

All 5 themes are defined in `/themes/*.nix`:

| Theme | Style | Base | FG |
|-------|-------|------|----|
| `monochrome` **(default)** | Pure grayscale | `#0a0a0a` | `#eeeeee` |
| `catppuccin-mocha` | Rich purples/blues | `#1e1e2e` | `#cdd6f4` |
| `kanagawa` | Warm earthy hues | `#181616` | `#c5c9c5` |
| `miasma` | Earthy/desert tones | `#222222` | `#c2c2b0` |
| `noctis` | Dark teal/blue | `#03191b` | `#b2cacd` |

Each theme file exports an attrset matching the schema:

```nix
{
  palette = { base = "#..."; dim = "#..."; ... };
  ansi = {
    normal = { black = "#..."; red = "#..."; ... };
    bright = { black = "#..."; red = "#..."; ... };
  };
  ui = { fg = "#..."; bg = "#..."; ... };
  syntax = { comment = "#..."; keyword = "#..."; ... };
  diagnostic = { error = "#..."; warning = "#..."; ... };
}
```

## Theme Library

`/themes/default.nix` is the library entry point. It provides:

### `themesLib.get`

The main access function:

```nix
themesLib.get = name:
  withRgb (withAliases (validateTheme name (normalizeThemeColors themes.${name})))
```

Processing chain:
1. **`normalizeThemeColors`** — Strips `#` prefix from all hex values
2. **`validateTheme`** — Checks every required token exists and is a valid 6-digit hex; fails at build time if invalid
3. **`withAliases`** — Adds 21 legacy uppercase aliases as top-level keys
4. **`withRgb`** — Generates `_RGB` suffixed attributes (e.g., `ui.fg_RGB`) with space-separated decimal RGB values for applications that need them

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
   let t = themesLib.get themeName; in
   [{
     path = "domains/terminal/ghostty/config/config";
     text = ''
       palette = 0=${t.ansi.black}
       palette = 1=${t.ansi.red}
       ...
       background = ${t.ui.bg}
       foreground = ${t.ui.fg}
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
| **theme-semantic-distinct** | All semantic role colors are distinct (no accidental duplicates) |
| **home-theme-override-test** | Full home-manager activation with an overridden theme |

The assertion library (`/lib/checks/theme/assertions.nix`) provides `require`, `requireDistinct`, and `requireInfix` helpers. Many domain render files embed inline checks.

## Source Map

| File | Role |
|------|------|
| `/themes/schema.nix` | Token layer definitions (44 tokens + 21 legacy) |
| `/themes/default.nix` | Theme library: import, normalize, validate, alias, RGB |
| `/themes/monochrome.nix` | Default grayscale theme |
| `/themes/catppuccin-mocha.nix` | Catppuccin Mocha theme |
| `/themes/kanagawa.nix` | Kanagawa theme |
| `/themes/miasma.nix` | Miasma (earthy/desert) theme |
| `/themes/noctis.nix` | Noctis (teal/blue) theme |
| `/lib/home/themeModule.nix` | `theme` option definition for home-manager |
| `/lib/checks/theme/` | Theme validation checks |
| `/lib/checks/theme/assertions.nix` | Check helper functions |

## Changing or Adding a Theme

1. Create a new theme file in `/themes/<name>.nix` following the schema
2. It will be auto-discovered by `/themes/default.nix`
3. Run `nix run .#lint-themes` to validate
4. Run `nix run .#lint-desktop` and `nix run .#lint-shell` to test renders
5. Set the theme in a host's `default.nix` via `theme = "your-theme-name";`

## Change Guidance

### Modifying theme system internals
- **`/themes/schema.nix`** — Defines the required token layers and fields. Adding a new token here requires updating all 5 theme files (`/themes/*.nix`) and potentially every `render.nix` that consumes them.
- **`/themes/default.nix`** — Theme library with normalization, validation, alias generation, and RGB conversion. Changes here affect all theme consumers and may break the existing 5 themes.
  - **`normalizeThemeColors`** strips `#` prefixes; be careful when changing this — some consumers expect bare hex.
  - **`withAliases`** generates uppercase legacy aliases (`FG`, `BG`, `RED`, etc.) used by many `render.nix` files. Adding new aliases here propagates everywhere.
  - **`withRgb`** generates `_RGB` suffixed space-separated decimal variants used by i3.
- **`/lib/home/themeModule.nix`** — The `theme` option definition. The option type is `enum` constrained to `lib.attrNames themesLib.themes`. Adding a theme updates this automatically.

### Modifying theme validation
- **`/lib/checks/theme/assertions.nix`** — Provides `require`, `requireDistinct`, `requireInfix` helpers used by many domain `render.nix` files for inline checks.
- **`/lib/checks/theme/semanticDistinct.nix`** — Ensures ERROR, SUCCESS, WARNING, INFO, COMMENT, MUTED are all distinct. Adding a new semantic role here requires updating the check.
- **`/lib/checks/theme/rendered.nix`** — Verifies rendered domain configs contain expected theme tokens. Update when adding domains or changing render output paths.
- **`/lib/checks/theme/override.nix`** — Tests theme override propagation. Works by picking an alternate theme (first alphabetically different from the host's theme) and verifying the rendered output changes.

### When adding a new domain that consumes themes
1. Create `render.nix` that uses `themesLib.get themeName` to access theme tokens
2. Optionally add `checks` in the render output list for built-in validation
3. The domain's rendered output is automatically included in `lint-desktop`/`lint-shell` if the domain has a `render.nix`
4. Run `nix run .#lint-themes` to verify

### Important constraints
- All 5 themes must always define the same tokens. Adding a token to the schema breaks all themes until they're updated.
- Legacy aliases (`FG`, `BG`, etc.) are computed from structured tokens in `withAliases`. If you deprecate a structured token, remove it from `withAliases` too.
- `_RGB` variants are generated for every string color value. Applications that consume these (i3) expect space-separated decimal `R G B` format.
