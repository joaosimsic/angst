# angst Refactor Plan

## Core Problems

| Problem | Impact |
|---|---|
| `hosts/` tracks machine-specific config in git | Conflicts on pull across machines |
| `user.env` parsing duplicated in 7 files | Fragile, inconsistent |
| `x86_64-linux` hardcoded in 5 files | Not portable |
| `proj/angst` hardcoded in 10 files | Broke if cloned to different path |
| `allowUnfree` hardcoded in 3 files | No opt-out |
| `themes/` imported from lower layers | 3 layer violations |
| No standalone HM without host dir | Can't build for Debian/TTY |
| 20 toolchains always installed unconditionally | Bloated on machines that need few |
| `hosts/` is a tracked concept you maintain | Unreasonable for unique machines |

## Two consumption modes

### Mode 1: Clone + local build

```bash
git clone <url> ~/proj/angst
cd ~/proj/angst
nixos-rebuild switch --flake .#default
# or: home-manager switch -f .#homeConfigurations.default
```

The flake reads `config/local.nix` (gitignored) directly. No system flake needed.

### Mode 3: Import as flake input

```nix
# /etc/nixos/flake.nix
{
  inputs.angst.url = "github:your/angst";
  outputs = { self, nixpkgs, angst, ... }: {
    nixosConfigurations.mybox = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        angst.nixosModules.default   # use as NixOS module
        {
          angst.domains.shell.nushell.enable = true;
          angst.capabilities.audio.enable = true;
        }
      ];
    };
  };
}
```

The flake exports `nixosModules.default` (and `homeModules.default`) — users set `angst.*` options manually in their own flake.

Both modes share the same internal module definitions. Mode 1 auto-populates `angst.*` from `config/local.nix`; Mode 3 expects the user to set them.

## Solution: Zero-setup, hostless, auto-detecting

No `hosts/` directory. No mandatory config file.

### Auto-detection (Mode 1)

When `config/local.nix` doesn't exist, the flake falls back to env vars + auto-detection:

| What | How |
|---|---|
| `system` | `builtins.currentSystem` |
| `graphical` | `builtins.getEnv "DISPLAY"` — if set → desktop domains |
| `repoPath` | Derive from `self.sourceInfo` |
| `allowUnfree` | `NIXPKGS_ALLOW_UNFREE` env var or default `true` |

### Profile logic (Mode 1 fallback)

- **Graphical** (DISPLAY set) — desktop domains: `wm.i3`, `bar.i3status`, `launcher.rofi`, `session.x11`, `terminal.ghostty`, `shell.nushell`, `shell.starship`, `terminal.zellij`, `editor.nvim`, `files.yazi`, `git.lazygit`, `llm.opencode`
- **TTY** (no DISPLAY) — shell domains: `shell.nushell`, `terminal.tmux`, `editor.nvim`, `git.lazygit`, `files.yazi`

### Opt-in mechanism

Beyond auto-detected domains, opt into additional ones:

- **Env var (Mode 1):** `ANGST_DOMAINS=term.ghostty,http-client.posting` — enable extra domains by path
- **Config file (Mode 1, persistent):** `config/local.nix` — gitignored, survives git ops
- **Explicit options (Mode 3):** Set `angst.domains.*` in the system flake

## New file layout

```
config/
├── local.nix.example     (tracked) — template
└── local.nix             (gitignored) — optional persistence

modules/
├── nixos.nix             (tracked) — NixOS module exporting options.angst.*
└── home.nix              (tracked) — HM module exporting options.angst.domains.*

domains/                  (tracked, mostly unchanged)
capabilities/             (tracked, mostly unchanged)
themes/                   (tracked, mostly unchanged)
toolchains/               (tracked, refactored)
lib/                      (tracked, refactored)
```

**Removed:** `hosts/`, `common/home.nix`, `common/user.nix`, `lib/build/mkHost.nix`

## Phase 1 — NixOS module

Create `modules/nixos.nix`:
- Options: `angst.enable`, `angst.domains.*`, `angst.capabilities.*`, `angst.theme`, etc.
- Config: enables home-manager + injects domain/capability modules
- This is what Mode 3 users import

Create `modules/home.nix`:
- Options: `angst.domains.*`, `angst.theme`
- Config: enables domains for standalone HM users

## Phase 2 — Central config loader

Create `lib/env.nix`:
- Reads `config/local.nix` (if exists)
- Falls back to `user.env` (backward compat)
- Overlays `ANGST_*` env vars (highest priority)
- Auto-detects missing values
- Returns resolved attrset compatible with `angst.*` options

## Phase 3 — Flake outputs

```nix
{
  nixosModules.default = import ./modules/nixos.nix;

  homeModules.default = import ./modules/home.nix;

  nixosConfigurations.default =   # Mode 1 auto-setup
    let cfg = import ./lib/env.nix { };
        pkgs = import nixpkgs { system = cfg.system; };
    in nixosSystem {
      system = cfg.system;
      modules = [
        self.nixosModules.default      # same module exported above
        cfg.asAngstModule              # auto-configure from env/config
        { nixpkgs = pkgs; }            # allowUnfree from cfg
      ];
    };

  homeConfigurations.default =   # standalone HM
    homeManagerConfiguration {
      modules = [
        self.homeModules.default
        cfg.asAngstModule
      ];
    };
}
```

## Phase 4 — Delete hosts/, replace with modules

- Delete `hosts/` directory entirely
- Delete `common/home.nix`, `common/user.nix`
- Move host content into `lib/env.nix` auto-detection where still relevant
- `lib/build/mkHost.nix` is removed — no longer needed

## Phase 5 — Fix duplication + hardcoded strings

- `lib/env.nix` replaces all 7 inline user.env parsings
- `system` from `builtins.currentSystem`
- `repoPath` from `self.sourceInfo`
- `allowUnfree` from env var or config

## Phase 6 — Fix architecture violations

- Pass theme colors as parameter instead of `import ../themes/default.nix`
- `capabilities/graphical.nix` → accept theme via module options, not import
- `lib/build/mkHome.nix` → accept `themesLib` as parameter

## Phase 7 — Make toolchains opt-in

- Currently all 20 toolchains imported unconditionally
- Move to opt-in via `angst.toolchains = [ "bash" "nix" "rust" ]`
- `modules/nixos.nix` includes defaults per profile (graphical vs tty)
- `ANGST_TOOLCHAINS` env var for Mode 1

## Migration order

1. `modules/nixos.nix` — NixOS module with `angst.*` options
2. `modules/home.nix` — HM module with `angst.domains.*` options
3. `lib/env.nix` — central config loader + auto-detection
4. `config/local.nix.example` — template
5. `.gitignore` update for `/config/local.nix`
6. Delete `hosts/`, `common/home.nix`, `common/user.nix`
7. Refactor `flake.nix` — use `lib/env.nix`, export modules
8. Refactor `lib/build/mkHome.nix` — accept pre-resolved config
9. Remove `lib/build/mkHost.nix`
10. Fix architecture violations
11. Make toolchains opt-in
12. `nix flake check` verification
