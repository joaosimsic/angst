# Config Symlink Hot-Reload Plan

## Context

Nvim domain (`domains/editor/nvim/`) seeds `~/.config/angst` from flake source once, then copies config via `home.activation`. Other domains use home-manager's `xdg.configFile` — configs live in read-only Nix store, no hot-reload. Want: all domains use symlinks from `~/.config/<app>` → source repo, so editing repo files instantly propagates.

**VM**: host repo at `/host/home/joao/proj/angst` (virtiofs). **Bare metal**: seed to `~/.config/angst` once, link there.

## Design

### Config source resolution

Activation-time check:
```bash
if [ -d "/host/home/joao/proj/angst" ]; then
  CFG_SRC="/host/home/joao/proj/angst"    # VM: virtiofs from host
else
  CFG_SRC="$HOME/.config/angst"           # bare metal: local seed
fi
```

### Per-domain deployment

Each domain with `config/` dir gets:
```
~/.config/<xdgName> → symlink → $CFG_SRC/domains/<cat>/<name>/config/
```

Templates (`.template` files): rendered at Nix build time, copied **through symlink** into source dir at activation. Plain files: available directly through symlink — edit in repo, app sees change instantly.

### Seed mechanism

`lib/domains/domain-config.nix` (new): shared module. `home.activation.seedAngstRepo` copies clean flake source to `~/.config/angst` once. Skips if `/host/...` path exists (VM) or already seeded.

### Domains with customXdg (nvim, i3, x11)

- **nvim**: remove `customXdg = true`. Base module handles config via new engine. Strip custom activation scripts from module.nix.
- **i3**: keep `customXdg = true`. Replace manual `xdg.configFile` with activation script that symlinks dir + copies build-time merged config (template + fragments + monitors).
- **x11**: no `config/` dir — no-op (unchanged).

### xdgFile mode (starship)

Single file symlink: `~/.config/starship.toml` → `$CFG_SRC/domains/shell/starship/config/starship.toml` (rendered from template first).

## Files

### Create

| File | Purpose |
|------|---------|
| `lib/domains/activation.nix` | `mkDomainActivation` engine — generates per-domain activation scripts (symlink + template render) |
| `lib/domains/domain-config.nix` | Shared module: `seedAngstRepo` activation, `domainConfig.sourceDir` option |

### Modify

| File | Change |
|------|--------|
| `lib/domains/module.nix` | Replace `xdg.configFile = mkXdgSymlinks {...}` with `mkDomainActivation {...}`. Add `renderTemplate` to baseModule args. |
| `lib/domains/default.nix` | Import `activation.nix` instead of `xdg.nix`. Pass `mkDomainActivation` to module.nix. |
| `core/home/default.nix` | Add `./domain-config.nix` import via `../../lib/domains/domain-config.nix` |
| `domains/editor/nvim/meta.nix` | Remove `customXdg = true` |
| `domains/editor/nvim/module.nix` | Remove `seedAngstRepo` and `nvimConfig` activations, `themeLua`/`themeLuaFile`/`tokens` bindings. Keep `programs.neovim.*` and `xdg.configFile."nvim/init.lua".enable = mkForce false`. |
| `domains/wm/i3/module.nix` | Replace `xdg.configFile` block with activation: symlink + copy merged config/monitors through symlink |
| `.gitignore` | Add patterns for rendered template outputs in source dirs |

### Delete

| File | Reason |
|------|--------|
| `lib/domains/xdg.nix` | Fully replaced by `activation.nix` |

### Verify (no changes expected)

| File | Reason |
|------|--------|
| `lib/build/mkHome.nix` | `renderTemplate` already in extraSpecialArgs |
| `core/system/virtualisation.nix` | VM detection is runtime, no compile-time flag needed |
| All other domains | No customXdg, no module.nix touching xdg.configFile — base module handles them |

## VM detection: runtime vs vmVariant

Plan uses runtime `/host` existence check. Alternative: set `angst.isVm` via `virtualisation.vmVariant` + pass through extraSpecialArgs. Runtime approach picked because:
- Same build artifact for VM and bare metal
- No threading through module system
- `/host` mount presence directly answers the question

If compile-time detection preferred, can add `isVm` to `extraSpecialArgs` later.

## Activation order

```
writeBoundary → seedAngstRepo → domain-<cat>-<name> (per domain)
```

Each domain activation is `entryAfter [ "seedAngstRepo" "writeBoundary" ]`.

## Verification

1. `nixos-rebuild build-vm --flake .#personal` — VM boots, check symlinks in `~/.config/`
2. `home-manager switch --flake .#joao` — bare metal, check symlinks
3. Edit a plain file in `domains/editor/nvim/config/lua/config/options.lua` — change visible in `~/.config/nvim/lua/config/options.lua` immediately (VM) or after rebuild (bare metal via seed update)
4. Check `~/.config/i3/config` contains merged fragments from rofi, ghostty, x11, i3status
5. Check `~/.config/starship.toml` is a symlink to rendered output in source dir
6. Check `~/.config/zellij/layouts/default.kdl` renders correctly (subdirectory template)
