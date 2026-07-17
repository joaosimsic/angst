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

`local/config.nix` (gitignored) is the **source of truth** for machine identity. **Profiles** (under `profiles/`) are reusable bundles of co-dependent configs — e.g., `desktop` enables i3 + bar + launcher + graphical capabilities as a unit. `lib/resolve.nix` reads config, applies env var overrides, and calls existing scan functions once — no duplicate scanning, no I/O in builders.

Existing domain/theme/capability/toolchain structure is **untouched** — only the wiring around them changes.

______________________________________________________________________

### Phase 1 — Core

All new files created; existing code still works alongside them.

#### `lib/resolve.nix` — single entry point

Reads `local/config.nix` (or `$ANGST_CONFIG` env var override), applies `ANGST_HOST`/`ANGST_USERNAME`/`ANGST_THEME`/`ANGST_PASSWORD` overrides, resolves toolchains (unset/`"*"` → all, list → specific), and calls existing scan functions once:

```nix
{
  # from config.nix + env overrides
  system, hostname, username, theme, password,
  monitors, profiles, toolchains,
  extraNixos, extraHome,

  # resolved from scan (evaluated once here, not by builders)
  scan = {
    domains = import ./lib/domains/default.nix { ... };
    themes = import ./themes/default.nix { ... };
    allToolchainPackages = [ ... ];  # flat list from toolchains/
    treesitterGrammars = [ ... ];
    capabilities = import ./capabilities/default.nix;
  };

  # resolved toolchain modules ready to import
  toolchainModules = [ ... ];   # flat list of module paths
}
```

**No `lib/scan/` directory** — the scan is just calling existing modules. The duplication was that they were called in 7 places; now they're called once in `resolve.nix`.

**Files to create:** `lib/resolve.nix`

#### Profiles (`profiles/`)

Each profile returns `{ hm, nixos }` — two lists of module paths:

```nix
# profiles/desktop.nix
{
  hm = [
    ../../domains/wm/i3/module.nix
    ../../domains/bar/i3status/module.nix
    ../../domains/launcher/rofi/module.nix
    ../../domains/terminal/ghostty/module.nix
  ];
  nixos = [
    ../../capabilities/graphical.nix
    ../../capabilities/audio.nix
    ../../capabilities/clipboard.nix
  ];
}
```

- Later profiles in the list override earlier ones (NixOS/HM module import order)
- On **NixOS**: `mkHost.nix` applies both `hm` + `nixos` parts
- On **non-NixOS**: `mkHome.nix` applies only the `hm` part
- No conditionals, no `mkIf` tricks, no `hosts/` directory fallback

| Profile | `hm` modules | `nixos` modules |
|---|---|---|
| `base` | nushell, starship, zellij, nvim, yazi, lazygit | network, git, search, monitoring, container capabilities |
| `desktop` | i3, i3status, rofi, ghostty, x11 | graphical, audio, clipboard capabilities |
| `development` | opencode, cursor-cli, sqlit, posting | (none) |
| `server` | (none) | ssh capability |
| `vm` | (none) | `lib/virtualisation/vm-profile.nix` (virtio/9p/SPICE, qemu mounts, VM detected keys) |

**Profile resolution** (`lib/profiles.nix`):

```nix
resolve = names: {
  hm  = lib.concatMap (n: profileMap.${n}.hm)  names;
  nixos = lib.concatMap (n: profileMap.${n}.nixos) names;
};
```

No toolchain imports in profiles — toolchain selection is driven by `config.nix.toolchains`.

**Files to create:** `profiles/base.nix`, `profiles/desktop.nix`, `profiles/development.nix`, `profiles/server.nix`, `profiles/vm.nix`, `lib/profiles.nix`

#### `lib/outputs.nix` — single output file

Replaces `lib/flake/default.nix` (397 LOC, fan-out 12) with one file:

```nix
# lib/outputs.nix
{ self, inputs, cfg, profiles }:
let
  mkHome = import ./build/mkHome.nix;
  mkHost = import ./build/mkHost.nix;

  hmModules = profiles.hm;
  nixosModules = profiles.nixos;
in
{
  homeConfigurations = {
    current = mkHome cfg hmModules;
    ${cfg.username}@${cfg.hostname} = mkHome cfg hmModules;
  };

  nixosConfigurations = {
    current = mkHost cfg hmModules nixosModules;
    ${cfg.hostname} = mkHost cfg hmModules nixosModules;
  };

  packages = { ... };      # angst CLI, vm CLI, shell wrapper
  apps = { ... };           # angst render/watch, vm, shell, lint-*, ssh deploy
  devShells = { ... };      # dev, safe, vm — all toolchains always available
  checks = { ... };         # lint-themes, lint-desktop, lint-shell, password, theme-rendered, etc.
}
```

All checks consume `cfg` directly — no re-parsing, no re-scanning. `check-parse-env` is deleted (no env file). Password check simplified to verify `password != "CHANGE_ME"`.

**Files to create:** `lib/outputs.nix`

#### `lib/build/mkHome.nix` — pure builder

```nix
# inputs, cfg → hmModules → homeManagerConfiguration
{ inputs, cfg, hmModules }:
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = import inputs.nixpkgs {
    system = cfg.system;
    config.allowUnfree = true;
  };
  extraSpecialArgs = {
    inherit (cfg) theme hostname monitors;
    inherit (cfg.scan) themes;
    userConfig = {
      username = cfg.username;
      homeDirectory = "/home/${cfg.username}";
    };
  };
  modules =
    hmModules
    ++ cfg.toolchainModules
    ++ (if cfg.extraHome != {} then [ cfg.extraHome ] else []);
}
```

#### `lib/build/mkHost.nix` — pure builder

```nix
# inputs, cfg, hmModules, nixosModules → nixosSystem
let
  hmConfig = mkHomeInternal { inherit inputs cfg; hmModules = hmModules; };
in
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = { ... };
  modules =
    nixosModules
    ++ (if builtins.pathExists ./local/hardware.nix then [ ./local/hardware.nix ] else [])
    ++ (if cfg.extraNixos != {} then [ cfg.extraNixos ] else [])
    ++ [
      { nixpkgs.hostPlatform = cfg.system; }
      inputs.home-manager.nixosModules.home-manager {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          inherit (hmConfig) extraSpecialArgs;
          users.${cfg.username} = { imports = hmConfig.modules; };
        };
      }
      { users.users.${cfg.username}.hashedPassword = lib.mkDefault cfg.password; }
    ];
}
```

No `common/`, `hosts/`, `user.env`, or env re-parsing involved.

**Files to modify:** `lib/build/mkHome.nix`, `lib/build/mkHost.nix`

______________________________________________________________________

### Phase 2 — `local/` + `flake.nix`

#### `local/` directory

- Create `local/` directory, add to `.gitignore`
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

  nixos = {};  # one-off NixOS config (replaces host-specific configuration.nix)
  home = {};   # one-off HM config (replaces host-specific home.nix)
}
```

No `local/home.nix`, `local/configuration.nix`, or any other fallback file. The `nixos` and `home` attrs are the only escape hatch. Auto-merged as additional modules by the builders.

Hardware: `nixos-generate-config --show-hardware-config > local/hardware.nix` (auto-imported if present).

Disko: `local/disk.nix`, applied with `sudo nix run github:nix-community/disko -- --mode disko local/disk.nix`.

**Files to create:** `local/config.nix` (template), `.gitignore` entry
**Files to delete:** `user.env`, `user.env.example`

#### `flake.nix` — thin wiring (~25 lines)

```nix
{
  inputs = { ... };  # unchanged

  outputs = { self, nixpkgs, home-manager, vm, shell, ... }@inputs:
    let
      inherit (import ./lib/resolve.nix { inherit inputs; }) cfg;
      profiles = import ./lib/profiles.nix { inherit (cfg) profiles; };
      outputs = import ./lib/outputs.nix { inherit self inputs cfg profiles; };
    in
    outputs;
}
```

`current` aliases exposed by `lib/outputs.nix` — `nixosConfigurations.current` and `homeConfigurations.current` always resolve from `local/config.nix`. No env vars needed at build time.

______________________________________________________________________

### Phase 3 — Cleanup

Delete all dead code:

| File/Dir | Reason |
|---|---|
| `lib/parseEnv.nix` | Replaced by `resolve.nix` |
| `lib/build/scanHosts.nix` | No more `hosts/` to scan |
| `lib/flake/default.nix` | Replaced by `lib/outputs.nix` |
| `lib/flake/homeConfigurations.nix` | Replaced by `lib/outputs.nix` |
| `lib/flake/checks.nix` | Replaced by `lib/outputs.nix` |
| `lib/flake/shared.nix` | Toolchain logic moved into `resolve.nix`; dev shell logic into `outputs.nix` |
| `common/` (entire dir) | Replaced by profiles |
| `hosts/` (entire dir) | Replaced by `local/config.nix` |
| `lib/virtualisation/` (entire dir) | `vm-profile.nix` moved to `profiles/vm.nix`; utility files kept only if still referenced |
| `user.env` | Replaced by `local/config.nix` |
| `user.env.example` | Replaced by `local/config.nix` template |
| Hardcoded `"proj/angst"` (10 files) | Centralized in `resolve.nix` |
| Hardcoded `"x86_64-linux"` (5 files) | Centralized in `resolve.nix` |
| Hardcoded `"allowUnfree"` (3 files) | Centralized in `resolve.nix` |

______________________________________________________________________

### Justfile

```just
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
    nix build .#nixosConfigurations.current

switch:
    sudo nixos-rebuild switch --flake .#current

hm:
    nix build .#homeConfigurations.current.activationPackage

hm-switch:
    nix build .#homeConfigurations.current.activationPackage && ./result/activate

check:
    nix flake check

dev:
    nix develop
```

`current` aliases derive user/host from `local/config.nix` via `resolve.nix` — no shell env vars, no `$USER@$HOST` guesswork.

______________________________________________________________________

### Invariants

- `local/` is **never tracked by git** (entire directory in `.gitignore`)
- Profiles are pure lists of NixOS/HM module paths — no special framework required
- Existing domain, theme, capability, toolchain structure is untouched
- Dev shell always has all toolchains available regardless of profile selection
- Toolchain selection is driven by `config.nix.toolchains`, not by profiles
- No fallback files — `config.nix.nixos` and `config.nix.home` are the only escape hatches
- `flake.nix` stays thin (~25 lines) — just inputs + output wiring
- Profiles compose via module ordering: later modules override earlier ones
- No `hosts/` directory — machine identity comes solely from `local/config.nix`
- No `angst passwd` CLI needed for bootstrap — `mkpasswd` is a standard system tool
- No env re-parsing in builders — `resolve.nix` evaluates everything once
