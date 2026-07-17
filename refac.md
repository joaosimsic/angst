# Introduction

The idea is to refac my whole nix repo, there are several flaws descripted on `analysis.md` that are apparent in build time and usage of the system.

# Use cases

There are various use cases that i want to cover that were made diffucult by the current architecture. I've been running this system on various hosts ranging from virtual machine, NixOS system and regular linux distro which have only access to nix package manager, and each host have its particularities like only using the system via ssh, only needing some specific toolchains for a debian server or running only home-manager in a regular linux distro.

# Problems

- There's no differentiation between home-manager related packages and NixOS configurations, they are all bundled together meaning i have little control how to run the system under different conditions.
- I'm forced to create a new host for every machine that ill run the system, even though i cant possibly predict if i will need the system to work in a completely different host. this obligates me to know before hand or to spend some time into creating a unique host if i ever want to use the system
- Since flake is based on git, it inherent all of the systems state such as user, themes and any other host specific configurations. Since i might use each host differently, i must be able to keep the system requirements outside git, allowing me to manage the way and reason im going to use it without have conflicts with new system versions or changes.
- There are several bottlenecks listed in ´analysis.md´ that makes the build time largely bigger than i must be.

! dont edit the text above

______________________________________________________________________

## Plan

### Core idea

`local/config.nix` (gitignored) is the **source of truth** for machine identity. **Profiles** (under `profiles/`) are reusable bundles of co-dependent configs — e.g., `desktop` enables i3 + bar + launcher + graphical capabilities as a unit. The builder functions become pure: they accept resolved configs + profile modules instead of re-parsing env and re-scanning internally.

Existing domain/theme/capability/toolchain structure is **untouched** — only the wiring around them changes.

______________________________________________________________________

### Phase 1 — `lib/resolve.nix` + `lib/scan/`

Two new modules that eliminate all duplicated scanning and env parsing:

**`lib/scan/default.nix`** — central scanner, evaluated once:

```nix
{
  domains = { homeEntries, nixosEntries, ... };     # from lib/domains/scan.nix
  themes = { lib, default, themes, ... };            # from themes/default.nix
  toolchains = { allPackages, treesitterGrammars };  # from toolchains/ scanning
  capabilities = { attrset of paths };               # from capabilities/default.nix
}
```

All downstream consumers use this instead of re-scanning directories or re-importing files.

**`lib/resolve.nix`** — single entry point for machine config:

- Reads `local/config.nix` (or `$ANGST_CONFIG` env var override)
- Applies `ANGST_HOST`, `ANGST_USERNAME`, `ANGST_THEME`, `ANGST_PASSWORD` overrides on top
- Resolves toolchains: unset → `"*"`, `"*"` → scan all, list → specific selection
- Returns a unified attrset: `{ system, hostname, username, theme, password, monitors, profiles, toolchains, extraNixos, extraHome, scan }`

**Files to create:** `lib/resolve.nix`, `lib/scan/default.nix`, `lib/scan/domains.nix`, `lib/scan/themes.nix`, `lib/scan/toolchains.nix`, `lib/scan/capabilities.nix`

______________________________________________________________________

### Phase 2 — Profiles (`profiles/`)

Each profile is a function returning `{ hm, nixos }` — two separate **modules** that share the same package set and theme context:

```nix
# profiles/desktop.nix
{ pkgs, themesLib, hostTheme, ... }: {
  hm = {
    domains.wm.i3.enable = true;
    domains.bar.i3status.enable = true;
    domains.launcher.rofi.enable = true;
    domains.terminal.ghostty.enable = true;
  };
  nixos = {
    capabilities.graphical.enable = true;
  };
}
```

- Later profiles in the list override earlier ones (NixOS/HM module import order)
- On **NixOS**: `mkHost.nix` applies both `hm` + `nixos` parts
- On **non-NixOS** (Mint, Debian, etc.): `mkHome.nix` applies only the `hm` part
- No conditionals, no `mkIf` tricks, no `hosts/` directory fallback

#### Profile definitions

| Profile | `hm` enables | `nixos` enables |
|---|---|---|
| `base` | nushell, starship, zellij, nvim, yazi, lazygit | network, git, search, monitoring, container capabilities; fstrim; zramSwap |
| `desktop` | i3, i3status, rofi, ghostty, x11 | graphical, audio, clipboard capabilities |
| `development` | opencode, cursor-cli, sqlit, posting | (nothing) |
| `server` | (nothing extra) | ssh capability |
| `default.nix` | Helper: `resolveProfiles [names] → { hm = [...], nixos = [...] }` | — |

**No toolchain imports in profiles.** Toolchain selection is driven by `config.nix.toolchains`.

**Files to create:** `profiles/base.nix`, `profiles/desktop.nix`, `profiles/development.nix`, `profiles/server.nix`, `profiles/default.nix`

______________________________________________________________________

### Phase 3 — Pure builders

Both builders accept a fully resolved config + profile modules. No internal I/O, no env parsing, no domain/theme re-scanning.

**`lib/build/mkHome.nix`**:

```nix
resolvedConfig: profileHmModules:
let
  cfg = resolvedConfig;
  pkgs = import cfg.scan.nixpkgs {
    system = cfg.system;
    config.allowUnfree = true;
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = pkgs;
  extraSpecialArgs = {
    inherit (cfg) theme hostname monitors;
    inherit (cfg.scan) themes;
    userConfig = {
      username = cfg.username;
      homeDirectory = "/home/${cfg.username}";
    };
  };
  modules =
    profileHmModules
    ++ toolchainModules cfg  # "*" → all via scan; list → select specific
    ++ (if cfg.extraHome != {} then [ cfg.extraHome ] else []);
}
```

**`lib/build/mkHost.nix`**:

```nix
resolvedConfig: profileHmModules: profileNixosModules:
let
  cfg = resolvedConfig;
  hmProfile = mkHomeInternal cfg profileHmModules;
in
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = { ... };
  modules =
    profileNixosModules
    ++ autoImportIfExists ./local/hardware.nix
    ++ (if cfg.extraNixos != {} then [ cfg.extraNixos ] else [])
    ++ [
      { nixpkgs.hostPlatform = cfg.system; }
      inputs.home-manager.nixosModules.home-manager {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          inherit (hmProfile) extraSpecialArgs;
          users.${cfg.username} = { imports = hmProfile.modules; };
        };
      }
      { users.users.${cfg.username}.hashedPassword = mkDefault cfg.password; }
    ];
}
```

No `common/`, `hosts/`, or `user.env` involved. Finishing this phase is the cutover point — after this, the old code is dead.

**Files to modify:** `lib/build/mkHome.nix`, `lib/build/mkHost.nix`

______________________________________________________________________

### Phase 4 — `local/` directory

- Create `local/` directory
- Add `local/` to `.gitignore`
- `local/config.nix` is the **sole source of machine identity** — no fallback files:

```nix
{
  system = "x86_64-linux";
  hostname = "personal";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development"];
  toolchains = "*";  # or ["bash" "nix" "php"] for server

  password = "CHANGE_ME";  # generated with `mkpasswd -m sha-512`

  monitors.primary = {
    name = "DP-1";
    resolution = "1920x1080";
    refresh = 144;
  };

  # One-off NixOS config (replaces host-specific configuration.nix quirks)
  nixos = {};

  # One-off HM config (replaces host-specific home.nix quirks)
  home = {};
}
```

No `local/home.nix`, `local/configuration.nix`, or any other fallback file. The `nixos` and `home` attrs in `config.nix` are the only escape hatch for truly one-off machine config.

`extraNixos` and `extraHome` in the resolved config are auto-merged as additional modules by the builders.

#### Hardware configuration

`nixos-generate-config --show-hardware-config > local/hardware.nix`. Auto-imported if present by `mkHost.nix`.

#### Disko (disk partitioning)

Same as original plan — `local/disk.nix`, applied with `sudo nix run github:nix-community/disko -- --mode disko local/disk.nix`.

**Files to create:** `local/config.nix` (template), `local/` dir entry in `.gitignore`
**Files to delete:** `user.env`, `user.env.example`

______________________________________________________________________

### Phase 5 — Rewire `flake.nix`

Replaces the current 171-line flake with thin wiring:

```nix
{
  inputs = { ... };  # unchanged

  outputs = { self, nixpkgs, home-manager, vm, shell, ... }@inputs:
    let
      resolvedConfig = import ./lib/resolve.nix { inherit inputs; };

      profileLib = import ./profiles/default.nix;
      profiles = profileLib.resolve resolvedConfig.profiles;

      mkHome = import ./lib/build/mkHome.nix inputs resolvedConfig;
      mkHost = import ./lib/build/mkHost.nix inputs resolvedConfig;

      flakeOutputs = import ./lib/outputs/default.nix {
        inherit self resolvedConfig mkHome mkHost profiles;
      };
    in
    flakeOutputs;
}
```

______________________________________________________________________

### Phase 6 — Output splitting

Split `lib/flake/default.nix` (397 LOC, fan-out 12) into focused submodules:

```
lib/outputs/
  default.nix          — orchestrates all of the above
  packages.nix
  apps.nix
  checks.nix
  devShells.nix
  homeConfigurations.nix
  nixosConfigurations.nix
```

**Files to delete:** `lib/flake/default.nix`, `lib/flake/homeConfigurations.nix`, `lib/flake/checks.nix`

______________________________________________________________________

### Phase 7 — Cleanup

Delete all dead code:

| File | Reason |
|---|---|
| `lib/parseEnv.nix` | Replaced by `resolve.nix` |
| `lib/build/scanHosts.nix` | No more `hosts/` to scan |
| `lib/flake/default.nix` | Split into `lib/outputs/` |
| `lib/flake/homeConfigurations.nix` | Split into `lib/outputs/` |
| `lib/flake/checks.nix` | Split into `lib/outputs/` |
| `common/` (entire directory) | Replaced by profiles |
| `hosts/` (entire directory) | Replaced by `local/config.nix` |
| `user.env` | Replaced by `local/config.nix` |
| `user.env.example` | Replaced by `local/config.nix` template |
| Hardcoded `"proj/angst"` (10 files) | Centralized in `resolve.nix` |
| Hardcoded `"x86_64-linux"` (5 files) | Centralized in `resolve.nix` |
| Hardcoded `"allowUnfree"` (3 files) | Centralized in `resolve.nix` |

`lib/flake/shared.nix` is kept but simplified — toolchain scanning moves into `lib/scan/toolchains.nix`.

______________________________________________________________________

### Justfile

```just
# Generate and store password hash (uses system mkpasswd, no flake dependency)
setup:
    @read -s -p "Enter password: " pass; echo; \
    read -s -p "Confirm password: " pass2; echo; \
    if [ "$$pass" != "$$pass2" ]; then echo "Passwords don't match"; exit 1; fi; \
    hash=$$(mkpasswd -m sha-512 <<<"$$pass"); \
    sed -i "s/CHANGE_ME/$$hash/" local/config.nix

disko:
    sudo nix run github:nix-community/disko -- --mode disko local/disk.nix

hardware:
    nixos-generate-config --show-hardware-config > local/hardware.nix

bootstrap: disko hardware
    @echo "Now write local/config.nix, run 'just setup', then 'just build'"

build:
    nix build .#nixosConfigurations.default

switch:
    sudo nixos-rebuild switch --flake .#default

hm:
    nix build .#homeConfigurations.${USER}@${HOST}

hm-switch:
    nix build .#homeConfigurations.${USER}@${HOST}.activationPackage && ./result/activate

check:
    nix flake check

dev:
    nix develop
```

Password flow: `just setup` prompts interactively, generates SHA-512 hash via standard `mkpasswd`, and substitutes the placeholder in `local/config.nix`. No `angst` CLI needed during bootstrap.

______________________________________________________________________

### Invariants

- `local/` is **never tracked by git** (entire directory in `.gitignore`)
- Profiles are pure NixOS/HM modules — no special framework required
- Existing domain, theme, capability, toolchain structure is untouched
- Dev shell always has all toolchains available regardless of profile selection
- Toolchain selection is driven by `config.nix.toolchains`, not by profiles
- No fallback files — `config.nix.nixos` and `config.nix.home` are the only escape hatches
- `flake.nix` stays thin — just inputs + output wiring
- Profiles compose via module ordering: later profiles override earlier ones
- No `hosts/` directory — machine identity comes solely from `local/config.nix`
- No `angst passwd` CLI needed for bootstrap — `mkpasswd` is a standard system tool
