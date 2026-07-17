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

### Phase 1 — `lib/resolve.nix`

Central config resolver. Single entry point that:

- Loads `local/config.nix`
- Returns a unified machine config: `{ system, username, theme, hostname, monitors, profiles, domains, password, ... }`
- Env vars (`ANGST_*`) override anything in the file
- Eliminates the 5-way duplicated `parseEnv` + path resolution across the codebase

**Files to create:** `lib/resolve.nix`
**Files to modify:** `flake.nix`, `lib/flake/default.nix`, `lib/build/mkHome.nix`, `lib/build/mkHost.nix`, `lib/flake/homeConfigurations.nix` — all switch to `lib/resolve.nix`

### Phase 2 — Unified profiles (`profiles/`)

Each profile is a function returning `{ hm, nixos }` — two separate modules that share the same package set and theme context:

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

- On **NixOS**: `mkHost.nix` applies both `hm` + `nixos` parts
- On **non-NixOS** (Mint, Debian, etc.): `mkHome.nix` applies only the `hm` part
- No conditionals, no `mkIf` tricks — the builder functions each pick the relevant sub-attr

Initial profiles:

- `profiles/base.nix` — shell, terminal, editor, `bash`, `nix`, `conf` toolchains (replaces `common/home.nix`)
- `profiles/desktop.nix` — i3, bar, rofi, ghostty + graphical capabilities
- `profiles/development.nix` — git, LLMs, **auto-scans all toolchains** (dynamic)
- `profiles/server.nix` — SSH, monitoring, `php`, `javascript` toolchains
- `profiles/default.nix` — helper to resolve a list of profile names → module list

Toolchains are explicitly imported per-profile (not auto-imported for every host). Profiles compose — `server.nix` only adds what `base.nix` doesn't already provide.

The dev shell always includes **all toolchains** (full auto-scan), regardless of which profiles the host selects.

**Files to create:** `profiles/` directory with modules
**Files to remove:** `common/` directory (home.nix, capabilities.nix, user.nix)

### Phase 3 — Pure builders

- `lib/build/mkHome.nix` refactored to accept `resolvedConfig` + list of profile `hm` modules — no internal env/theme/domain resolution
- `lib/build/mkHost.nix` refactored to accept `resolvedConfig` + list of profile `hm` + `nixos` modules — compose NixOS + HM cleanly
- Both become thin, predictable functions with explicit inputs

### Phase 4 — `local/` directory

- Create `local/` directory, add to `.gitignore`
- `local/config.nix` becomes the source of truth:
  ```nix
  {
    system = "x86_64-linux";
    username = "joao";
    profiles = [ "base" "desktop" "development" ];
    theme = "miasma";
    hostname = "personal";
    password = "...";
    monitors.primary = { name = "DP-1"; resolution = "1920x1080"; ... };
    domains.terminal.ghostty.enable = false;  # per-machine override
  }
  ```
- Delete `user.env` + `user.env.example`
- Update `lib/resolve.nix` to default to `local/config.nix`

#### Hardware configuration

`nixos-generate-config --show-hardware-config > local/hardware.nix` generates machine-specific hardware config (filesystems, kernel modules, etc.). `mkHost.nix` auto-imports `local/hardware.nix` if it exists, keeping `local/config.nix` clean — just identity + profile selection.

#### Disko (disk partitioning)

`local/disk.nix` defines the disk layout for each machine (dual boot, full disk, LVM, etc.) using disko. Applied with:

```
sudo nix run github:nix-community/disko -- --mode disko local/disk.nix
```

Example for a full-disk ext4 system:

```nix
{
  disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
        };
        root = {
          size = "100%";
          content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };
        };
      };
    };
  };
}
```

Machines that don't need disko (existing installs, non-NixOS) simply don't have `local/disk.nix`.

Full bootstrap on a blank machine:
1. Write `local/disk.nix`
2. `sudo nix run github:nix-community/disko -- --mode disko local/disk.nix`
3. `nixos-generate-config --show-hardware-config > local/hardware.nix`
4. Write `local/config.nix` — pick profiles, set username/theme
5. Build or switch

### Phase 5 — Output splitting

Split `lib/flake/default.nix` (397 LOC, fan-out 12) into focused submodules:

- `lib/outputs/packages.nix`
- `lib/outputs/apps.nix`
- `lib/outputs/checks.nix`
- `lib/outputs/devShells.nix`
- `lib/outputs/homeConfigurations.nix`
- `lib/outputs/nixosConfigurations.nix`
- `lib/outputs/default.nix` — orchestrates all of the above

### Phase 6 — Consolidation

- Move domain/theme/toolchain/capability scanning into `lib/scan/` (evaluate once, pass around)
- Eliminate hardcoded `"proj/angst"`, `"x86_64-linux"`, `"allowUnfree"` into centralized constants in `lib/resolve.nix`
- Remove `common/` directory
- Remove `hosts/` directory — config now lives in `local/config.nix` or profiles
- Remove `user.env` + `user.env.example`

### Justfile

A `justfile` automates common workflows, keeping setup minimal:

```just
disko:
    sudo nix run github:nix-community/disko -- --mode disko local/disk.nix

hardware:
    nixos-generate-config --show-hardware-config > local/hardware.nix

bootstrap: disko hardware
    @echo "Now write local/config.nix and run: just build"

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

### Invariants

- `local/` is **never tracked by git**
- Profiles are pure NixOS/HM modules — no special framework required
- Existing domain, theme, capability, toolchain structure is untouched
- Dev shell always has all toolchains available regardless of profile selection
- `flake.nix` stays thin — just inputs + output wiring
