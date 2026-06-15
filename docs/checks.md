# Config checks

Run the full check suite before committing config changes:

```bash
nix run .#check
```

This is equivalent to `nix flake check --print-build-logs`.

## What gets checked

| Check | Catches |
|-------|---------|
| `lint-themes` | Broken themes; missing or invalid theme placeholders; theme-only template renders |
| `lint-desktop` | Invalid i3 and i3status configs (all themes) |
| `lint-shell` | Invalid starship and nushell configs (all themes) |
| `theme-rendered` | Theme tokens not appearing in rendered ghostty, starship, nushell, zellij output |
| `theme-override` | `theme` option override not propagating into configs |
| `theme-semantic-distinct` | Duplicate semantic color roles within a theme |
| `home-theme-override-test` | home-manager activation for theme override config |
| `nixos-personal` | Full NixOS system evaluation for the personal host |
| `home-joao` | Standalone home-manager activation for the personal profile |

`lint-themes` validates placeholders like `{{BG}}` and `{{FONT_FAMILY}}`. Domain-specific placeholders (e.g. `{{I3STATUS_PATH}}` in the i3 bar template) are injected at render time by domain modules and validated by integration checks (`lint-desktop`, `lint-shell`, etc.).

## Individual lints

Faster targeted checks:

```bash
nix run .#lint-themes    # eval-only, fastest
nix run .#lint-desktop   # i3 + i3status per theme
nix run .#lint-shell     # starship + nushell per theme
```

## CI

GitHub Actions runs `nix flake check` on every push to `main` and on pull requests (see `.github/workflows/checks.yml`).

The first CI run builds the full NixOS closure and may take a while. Subsequent runs reuse the Nix store cache.
