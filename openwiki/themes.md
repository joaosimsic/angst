# Themes

angst has a **compact color-theme system** that powers consistent theming across ~15 rendered applications (plus terminals, prompts, WM). Themes are pure data, validated at build time, and rendered into domain configs at eval time.

## Token Schema (`systems/theme/internal/schema.nix`)

13 tokens total: **9 palette + 4 ansi**. Optional `contrastThreshold` (default 4.5) tunes the contrast guard per theme.

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

## Available Themes (8)

Defined as plain attrsets in `systems/theme/themes/<name>.nix` (auto-discovered by `systems/theme/internal/catalog.nix`; invalid files surface as catalog diagnostics and fail `lint-themes`):

| Theme | Style | Background | Accent |
|-------|-------|------------|--------|
| `catppuccin-mocha` | Rich purples/blues | `#1e1e2e` | `#f9e2af` |
| `github` | GitHub dark | `#010409` | `#ff7b72` |
| `gotham` | Dark teal/blue-green | `#0c1014` | `#c23127` |
| `kanagawa` | Warm earthy hues | `#181616` | `#c4b28a` |
| `lotus` | Light/warm lotus | `#f2ecbc` | `#c84053` |
| `miasma` **(default)** | Earthy/desert tones | `#272727` | `#b36d43` |
| `noctis` | Dark teal/blue | `#03191b` | `#e4b781` |
| `rose-pine` | Rose-pine dusk | `#191724` | `#eb6f92` |

```nix
# themes/miasma.nix (excerpt)
{
  palette = {
    background = { base = "#272727"; variant = "#232323"; };
    surface    = { base = "#78824b"; variant = "#5f875f"; };
    foreground = { base = "#c9a554"; variant = "#d7c483"; };
    accent     = { base = "#b36d43"; variant = "#bb7744"; };
    dim = "#685742";
  };
  ansi = { error = "#d9534f"; warn = "#df9f28"; info = "#5f9ea0"; success = "#6e9643"; };
}
```

## Normalization and Validation (`systems/theme/default.nix`)

`themeSys` (imported in `flake.nix` as `import ./systems/theme/default.nix { inherit lib; }`) exposes:

- `normalizeTheme` — strips leading `#` from every hex value;
- `validate` / `validateOrThrow` (via `internal/schema.nix`) — enforces all 13 required paths exist and are valid 6-digit hex (throws otherwise);
- `withRgb` — walks every bare-hex string and adds a `<path>_RGB` sibling (`"r g b"` integer triple) for apps that need numeric colors (e.g. qt `kdeglobals`); non-hex strings and functions are skipped, so `safe.*` tokens get `_RGB` siblings too;
- `get name` — returns the theme plus `isDark`/`colorScheme` (WCAG luminance, sRGB gamma 2.4) and contrast-checked `safe.*` tokens;
- `contrast` — `{ ensureContrast, pickContrast, contrastRatio, relativeLuminance }` helpers.

`safe` tokens (all threshold-gated via `pickContrast`: first passing candidate in intent order wins, else the highest-ratio candidate):

- `foregroundOnSurfaceVariant/Base`, `foregroundOnAccentVariant/Base`, `foregroundOnBgVariant` — light-first text candidates for a given surface;
- `surfaceVariantOnForegroundVariant` — background pick for foreground-on-surface combos (used by zellij active tab);
- `textOn bg` — function for arbitrary backgrounds (used by i3 urgent-workspace text, zellij/tmux mode chips, GTK `gtk.css`).

Palettes where no candidate reaches 4.5 (e.g. earthy mid-tones in miasma/lotus) resolve best-effort to the highest-ratio pair — still the best available, but below WCAG AA. Prefer light text on saturated surfaces and dark text on light surfaces when authoring themes.

All 8 themes must load (`checks/theme/entries.nix`); the four `ansi.*` roles must be mutually distinct (`checks/theme/semanticDistinct.nix`); every theme passes through the render checks (`checks/theme/rendered.nix`).

## Rendering Integration

Domains consume themes via `render.nix` (see [Domains](domains.md)):

```nix
t = themeSys.get themeName;   # all tokens + _RGB + safe.*
```

`lib/render.nix` (`renderDomainOutputsFor`) evaluates every enabled domain's `render.nix` for the host's theme (or a `themeOverride`) and produces `[{ path, text, checks? }]`. `angst render` writes those files into the repo (and `angst watch` re-renders on changes). The override machinery powers the `home-theme-override-test` check, which builds a home configuration with an alternate theme and asserts the override propagated into rendered outputs (e.g. ghostty background).

## Domain Contract

Backgrounds are the domain's choice; **text is always theme-resolved**. Renders must never compose raw `fg` pairs by hand — route every text color through `safe.*` (fixed pairs) or `safe.textOn bg` (arbitrary backgrounds). Per-render `checks` assert a 3.0 contrast floor on resolved pairs (4.5 target; best-effort palettes may land between).

Exemptions (documented, not tech debt):

- Semantic hues: `ansi.warn/error` text where the hue itself carries meaning (i3status states, exit codes, ly errors, starship). Hue loss would be worse than sub-4.5 contrast.
- Decorations: borders, separators, frames, indicators — no text, no floor.
- Slot exports: posting/sqlit/opencode global `foreground`/`background` slots (app pairs internally; both slots already pass ≥4.5 everywhere).
- Known limits: lazygit sets only `selectedLineBgColor` (no selected-line fg slot), so the background moved to `background.variant` (worst pair 4.07, was 1.0); opencode diff line-number fg has no theme slot.

## Change Guidance

- **Add a theme**: copy an existing `systems/theme/themes/<name>.nix`, set all 13 tokens, run `nix run .#lint-themes` (or `nix build .#checks.x86_64-linux.lint-themes`).
- **Rename/remove tokens**: update `systems/theme/internal/schema.nix`, every theme file, and every `render.nix` that references tokens — validation fails loudly on missed paths.
- **Contrast concerns**: adjust `contrastThreshold` per theme; accessibility-sensitive renders must use `safe.*` / `safe.textOn`, never raw pairs. Best-effort fallbacks are documented above — check ratios before lowering the threshold.
- Renders that need RGB ints (qt) must use the `_RGB` variants, not re-parse hex themselves.
- GTK apps get `gtk-3.0/gtk.css` + `gtk-4.0/gtk.css` `@define-color` mappings (Adwaita base + theme accents); Qt gets a full `kdeglobals`.
