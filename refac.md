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

Each profile is a standard NixOS/HM module that enables a bundle of related domains, capabilities, packages, and toolchains:

- `profiles/base.nix` — shell, terminal, editor, `bash`, `nix`, `conf` toolchains (replaces `common/home.nix`)
- `profiles/desktop.nix` — i3, bar, rofi, ghostty, graphical capabilities
- `profiles/development.nix` — git, LLMs, **auto-scans all toolchains** (dynamic, like `toolchains/default.nix` does today)
- `profiles/server.nix` — SSH, monitoring, `php`, `javascript` toolchains
- `profiles/default.nix` — helper to resolve a list of profile names → module list

Toolchains are explicitly imported per-profile (not auto-imported for every host). Profiles compose — `server.nix` only adds what `base.nix` doesn't already provide.

Domain routing is already handled by `meta.building` — profiles just enable things and the existing system dispatches them correctly.

The dev shell always includes **all toolchains** (full auto-scan), regardless of which profiles the host selects.

**Files to create:** `profiles/` directory with modules
**Files to remove:** `common/` directory (home.nix, capabilities.nix, user.nix)

### Phase 3 — Pure builders

- `lib/build/mkHome.nix` refactored to accept `resolvedConfig` + `profileModules` — no internal env/theme/domain resolution
- `lib/build/mkHost.nix` refactored to accept `resolvedConfig` + `profileModules` — compose NixOS + HM cleanly
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

Minimal setup for a new machine is:
1. `nixos-generate-config --show-hardware-config > local/hardware.nix`
2. Edit `local/config.nix` — pick profiles, set username/theme
3. Build or switch

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
hardware:
    nixos-generate-config --show-hardware-config > local/hardware.nix

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

- `local/config.nix` is **never tracked by git**
- Profiles are pure NixOS/HM modules — no special framework required
- Existing domain, theme, capability, toolchain structure is untouched
- Dev shell always has all toolchains available regardless of profile selection
- `flake.nix` stays thin — just inputs + output wiring
