# Themes

angst has a **compact color-theme system** that powers consistent theming across ~15 rendered applications (plus terminals, prompts, WM). Themes are pure data, validated at build time, and rendered into domain configs at eval time.

## Token Schema (`/themes/schema.nix`)

13 tokens total: **9 palette + 4 ansi**.

### Palette (9)

| Token | Role |
|-------|------|
| `palette.background.base` | Main UI background |
| `palette.background.variant` | Darker background (panels, surfaces) |
| `palette.surface.base` | Surface tone |
| `palette.surface.variant` | Surface variant |
| `palette.foreground.base` | Main text / foreground |
| `palette.foreground.variant` | Bright / highlighted text |
| `palette.accent.base` | Primary accent |
| `palette.accent.variant` | Secondary accent |
| `palette.dim` | Muted / dim / comment |

### ANSI (4)

| Token | Role |
|-------|------|
| `ansi.error` | Error / danger |
| `ansi.warn` | Warning |
| `ansi.info` | Information |
| `ansi.success` | Success |

## Available Themes (9)

Defined as plain attrsets in `/themes/<name>.nix`:

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
| `rose-pine` | Rose-pine dusk | `#191724` | `#eb6f92` |

```nix
# themes/monochrome.nix (excerpt)
{
  palette = {
    background = { base = "#0a0a0a"; variant = "#0a0a0a"; };
    surface    = { base = "#858585"; variant = "#a7a7a7"; };
    foreground = { base = "#8f8f8f"; variant = "#eeeeee"; };
    accent     = { base = "#b3b3b3"; variant = "#919191"; };
    dim = "#9b9b9b";
  };
  ansi = { error = "#9b9b9b"; warn = "#b3b3b3"; info = "#8f8f8f"; success = "#a7a7a7"; };
}
```

## Normalization and Validation (`/themes/default.nix`)

`themesLib` (imported in `flake.nix` as `import ./themes/default.nix { inherit lib; }`) exposes:

- `normalizeTheme` — strips leading `#` from every hex value;
- `validateTheme` — enforces all 13 required paths exist and are valid 6-digit hex (throws otherwise);
- `withRgb` — walks every token string and adds a `<path>_RGB` sibling (`"r g b"` integer triple) for apps that need numeric colors (e.g. i3);
- `get name` — returns the theme plus `safe.*` contrast-checked tokens: `ensureContrast` computes contrast ratios (default threshold 4.5; e.g. `miasma` opts out via `contrastThreshold = 0`) and provides `surfaceVariantOnForegroundVariant` for foreground-on-surface combinations.

All 9 themes must load (`checks/theme/entries.nix`); the four `ansi.*` roles must be mutually distinct (`checks/theme/semanticDistinct.nix`); every theme passes through the render checks (`checks/theme/rendered.nix`).

## Rendering Integration

Domains consume themes via `render.nix` (see [Domains](domains.md)):

```nix
t = themesLib.get themeName;   # all tokens + _RGB + safe.*
```

`lib/render.nix` (`renderDomainOutputsFor`) evaluates every enabled domain's `render.nix` for the host's theme (or a `themeOverride`) and produces `[{ path, text, checks? }]`. `angst render` writes those files into the repo (and `angst watch` re-renders on changes). The override machinery powers the `home-theme-override-test` check, which builds a home configuration with an alternate theme and asserts the override propagated into rendered outputs (e.g. ghostty background).

## Change Guidance

- **Add a theme**: copy an existing `/themes/<name>.nix`, set all 13 tokens, run `nix run .#lint-themes` (or `nix build .#checks.x86_64-linux.lint-themes`).
- **Rename/remove tokens**: update `themes/schema.nix`, every theme file, and every `render.nix` that references tokens — `validateTheme` will fail loudly on missed paths.
- **Contrast concerns**: adjust `contrastThreshold` per theme; `safe.*` tokens are what accessibility-sensitive renders should use.
- Renders that need RGB ints (i3) must use the `_RGB` variants, not re-parse hex themselves.
