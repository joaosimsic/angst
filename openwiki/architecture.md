# Architecture

angst is structured as a Nix flake with a clear separation of concerns: machine descriptors (hosts), system features (capabilities), user-space configs (domains), a unified theme system, and supporting build infrastructure.

## Flake Structure

The root `flake.nix` (`/flake.nix`) is a thin ~30-line orchestration layer:

```
inputs:
  nixpkgs           (nixos-unstable)
  home-manager      (nix-community/home-manager)
  vm                (./tools/vm, local flake)
  shell             (./tools/shell, local flake)

outputs:
  themesLib         -> import ./themes/default.nix
  cfg               -> import ./lib/read-config.nix   (reads local/config.nix)
  pkgs              -> nixpkgs with nixpkgs-config
  profiles          -> import ./profiles/default.nix  (composes enabled domains/caps)
  final             -> import ./lib/flake/outputs.nix { self, inputs, cfg, profiles }
```

The flake delegates entirely to `lib/flake/outputs.nix` which produces `nixosConfigurations`, `homeConfigurations`, `packages`, `devShells`, `apps`, and `checks`. No host scanning, no manual configuration iteration — just a single `cfg` object passed through the build pipeline.

## Configuration via local/config.nix

Instead of per-host directories, a single `local/config.nix` (gitignored) defines the full machine identity:

```nix
{
  system = "x86_64-linux";
  hostname = "nixos";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development"];
  password = "$y$j9T$...";    # hashed via `just password`
  monitors = {
    primary = { name = "DP-1"; resolution = "1920x1080"; refreshRate = 144; position = "0x0"; };
  };
  nixos = { keyboardLayout = "br-abnt2"; };
  toolchains = "*";            # "*" means all, or a list for minimal setups
}
```

`lib/read-config.nix` (`/lib/read-config.nix`) loads this file and constructs the unified `cfg` object consumed by every build function:

| cfg key | Source | Purpose |
|---------|--------|---------|
| `cfg.system` | `config.system or "x86_64-linux"` | Target architecture |
| `cfg.hostname` | `config.hostname or "nixos"` | Machine hostname |
| `cfg.username` | `config.username or "user"` | Primary user |
| `cfg.theme` | `config.theme or "monochrome"` | Active theme name |
| `cfg.password` | `config.password or "!"` | Hashed password |
| `cfg.monitors` | `config.monitors or {}` | Display configuration |
| `cfg.profiles` | `config.profiles or ["base"]` | Active profile list |
| `cfg.toolchains` | `config.toolchains or "*"` | Language toolchain filter |
| `cfg.repoPath` | `config.repoPath or "proj/angst"` | Relative repo path from $HOME |
| `cfg.extraNixos` | `config.nixos or {}` | Per-machine NixOS extras |
| `cfg.extraHome` | `config.home or {}` | Per-machine home-manager extras |
| `cfg.scan.domains` | Auto-discovered domain entries | Domain framework |
| `cfg.scan.themes` | Theme library | Theme access |
| `cfg.scan.allToolchainPackages` | All enabled toolchain packages | Aggregated packages |
| `cfg.scan.treesitter` | Tree-sitter grammar builder | Cross-glibc parsers |

This approach replaces the old `hosts/` directories and `user.env` parsing: everything lives in one gitignored file, readable at both Nix build time and by Rust/script tooling.

## Capabilities — System Feature Modules

Capabilities (`/capabilities/`) are opt-in NixOS modules auto-discovered by `/capabilities/default.nix`. Each file defines an option `capabilities.<name>.enable` and conditionally enables system services.

| Capability | Service |
|------------|---------|
| `audio` | PipeWire with ALSA/PulseAudio compat |
| `graphical` | X11, LightDM (themed background), libinput, dbus, XDG portals |
| `network` | NetworkManager, wget, curl, unzip |
| `container` | Docker, Podman, kubectl, lazydocker |
| `ssh` | OpenSSH client/server, key-only auth, agent forwarding |
| `git` | Git, lazygit |
| `clipboard` | wl-clipboard, xclip |
| `monitoring` | System monitoring tools |
| `search` | FSearch (GNOME) indexer |

Capabilities are **enabled through profile composition** — each profile uses the `mkCap` helper to activate the capabilities it needs. For example, the `base` profile enables `network`, `git`, `search`, `monitoring`, and `container`; the `desktop` profile adds `graphical`, `audio`, and `clipboard`. The `vm` profile enables `ssh` and the VM detection modules. The full capability set for a host is the union of all enabled profiles, composed in `profiles/default.nix`.

## Build System

The build system is organized around a shared `cfg` object (from `lib/read-config.nix`) that flows through every builder.

### mkHome.nix (`/lib/build/mkHome.nix`)

Constructs a home-manager configuration using the `cfg` object:

1. Receives `{ inputs, self, cfg, hmModules, vmTool, shellTool, angstTool, themeOverride? }`
2. Resolves effective theme (with override support for tests)
3. Builds `userCfg` from `cfg.username`
4. Scans domains via `cfg.scan.domains` to produce `appHomeModules`
5. Imports theme module from `modules/home/themeModule.nix`
6. Calls `home-manager.lib.homeManagerConfiguration` with:
   - `extraSpecialArgs` — keys: `hostname`, `monitors`, `repoPath`, `themes`, `themesLib`, `hostName`, `userConfig`, `theme`, `flakeSelf`
   - Modules: `modules/home`, `themeModule`, app domain modules, toolchain modules, extraHome, plus VM/shell/angst tool packages
7. Optionally includes `cfg.extraHome` for one-off config

**Key design choice**: Unlike the old `mkHome.nix`, the new version does NOT parse `user.env` or resolve hosts — all that is handled upstream by `lib/read-config.nix`. The builder receives a fully resolved `cfg` and focuses purely on home-manager configuration construction.

### mkNixos.nix (`/lib/build/mkNixos.nix`) — replaces mkHost.nix

Constructs a full NixOS system configuration:

1. Receives `{ inputs, self, cfg, hmModules, nixosModules, themeOverride? }`
2. Loads `pkgs` from `cfg.system`, resolves effective theme
3. Scans `modules/vm/` for VM detection and runtime:
   - `detect.nix` — Sets `angst.isQemuVm` option
   - `runtime.nix` — Conditional bootloader
   - `vm-variant.nix` — QEMU VM resources (4 vCPUs, 4GiB RAM)
   - `vm-profile.nix` — 9p mounts, SPICE, SSH keys
   - `host-mount.nix` — Config symlink to host mount
4. Imports `capabilities/ssh.nix` unconditionally
5. Sets `users.users.<username>.hashedPassword = lib.mkDefault cfg.password`
6. Wires home-manager into NixOS with matching `extraSpecialArgs`
7. Optionally loads `local/hardware.nix` for per-machine hardware configuration
8. Optionally includes `cfg.extraNixos` for one-off NixOS config

**specialArgs** passed to both NixOS and home-manager: `hostname`, `monitors`, `repoPath`, `themes`, `themesLib`, `hostName`, `userConfig`, `theme`, `flakeSelf`.

```nix
# Core structure of mkNixos.nix:
modules = [
  { nixpkgs.hostPlatform = cfg.system; }
  ++ nixosModules                              # profile-generated NixOS modules
  ++ appNixosModules                           # domains with nixos.nix
  ++ [ ../../modules/nixos ]                   # base NixOS module (font, keyboard)
  ++ (if hardwarePath != null then [ hardwarePath ] else [])
  ++ [ ../../modules/vm/detect.nix              # VM detection and runtime
       ../../modules/vm/runtime.nix
       ../../modules/vm/vm-variant.nix
       ../../modules/vm/vm-profile.nix
       ../../modules/vm/host-mount.nix
       ../../capabilities/ssh.nix
       ({ ... }: { users.users.${cfg.username}.hashedPassword = ...; })
       inputs.home-manager.nixosModules.home-manager
       { home-manager = { ... }; }
     ]
];
```

## Configuration Resolution (local/config.nix)

Instead of a `user.env` file and `hosts/` directories, a single `local/config.nix` provides all per-machine settings. This file is gitignored and loaded by `lib/read-config.nix` at build time.

### Resolution Priority

The `lib/read-config.nix` loader resolves each field with a clean fallback chain — every value has a sensible default:

| Setting | Source | Default |
|---------|--------|---------|
| Host target | `config.hostname` | `"nixos"` |
| Username | `config.username` | `"user"` |
| Theme | `config.theme` | `"monochrome"` |
| Password | `config.password` | `"!"` (locked) |
| Profiles | `config.profiles` | `["base"]` |
| Toolchains | `config.toolchains` | `"*"` (all) |
| System | `config.system` | `"x86_64-linux"` |

### Consumption Points

| Context | How config is read | Files |
|---------|-------------------|-------|
| Build-time Nix | `builtins.readDir` + `import` via `read-config.nix` | `lib/read-config.nix`, `flake.nix` |
| VM CLI runtime | Rust `read_env_value()` reads `local/config.nix`? | `tools/vm/crates/vm-cli/src/runner/vm.rs` |
| Shell CLI runtime | Rust `read_env_value()` reads env vars | `tools/shell/src/runner.rs` |
| Password setup | `just password` writes password to `local/config.nix` | `scripts/angst.sh`, `justfile` |

### Profile Composition

Profiles (`/profiles/`) are the mechanism that replaced host-specific `home.nix` and `configuration.nix` files. Each profile is a pure function returning `{ hm = [...]; nixos = [...]; }` lists of module imports:

```nix
# profiles/base.nix — always applied
{ mkDomainEnable, mkCap }:
{
  hm = [
    (mkDomainEnable "shell.nushell")
    (mkDomainEnable "shell.starship")
    (mkDomainEnable "terminal.zellij")
    (mkDomainEnable "editor.nvim")
    (mkDomainEnable "git.lazygit")
  ];
  nixos = [
    (mkCap "network")
    (mkCap "container")
    (mkCap "search")
    (mkCap "monitoring")
    (mkCap "git")
  ];
}
```

`mkDomainEnable` validates that the domain name exists (throwing a clear error for typos). `mkCap` imports the capability module and enables it. Both are defined in `profiles/default.nix` along with the `profileMap` that maps profile names to their implementations.

## Virtualization / VM Detection

The repository has sophisticated VM support for development, now housed in `modules/vm/`:

1. **Detection** (`modules/vm/detect.nix`, `is-qemu-vm.nix`): Sets `angst.isQemuVm` based on whether the flake path starts with `/host` (indicating a 9p host mount from QEMU)
2. **VM Profile** (`vm-profile.nix`): 9p filesystem mounts, SPICE vdagent, SSH key injection, monitor override
3. **Boot** (`runtime.nix`): `systemd-boot` on bare metal, grub disabled in VM
4. **Host Mount** (`host-mount.nix`): Symlinks `/home/$USER/.config/angst` to the host 9p path for live editing
5. **Specialisation** (`specialisation.nix`): Bootable specialisation entry for VM mode without rebuild-vm
6. **vmVariant** (`vm-variant.nix`): QEMU VM config via `virtualisation.vmVariant` (4 vCPUs, 4GiB RAM, 16GB disk)

## Data Flow

```
local/config.nix                       profiles/base.nix, desktop.nix, ...
  ├─ hostname, username, theme, password  ├─ mkDomainEnable calls
  ├─ profiles = ["base" "desktop"]        ├─ mkCap calls
  ├─ monitors, nixos, home, toolchains    └─ resolved by profiles/default.nix
  ▼                                        ▼
lib/read-config.nix                    profiles/default.nix
  └─ cfg object                          ├─ hm module list
     ├─ cfg.system                        └─ nixos module list
     ├─ cfg.hostname                       ▼
     ├─ cfg.username                   lib/flake/outputs.nix
     ├─ cfg.theme                        ├─ mkHome (lib/build/mkHome.nix)
     ├─ cfg.password                     │   ├─ modules/home (default, domain, treesitter)
     ├─ cfg.monitors                     │   ├─ themeModule (modules/home/themeModule.nix)
     ├─ cfg.profiles                     │   ├─ app domain modules (auto-generated)
     ├─ cfg.toolchains                   │   ├─ toolchain modules (cfg.toolchainModules)
     ├─ cfg.extraNixos                   │   └─ vmTool, shellTool, angstTool packages
     ├─ cfg.extraHome                    ├─ mkNixos (lib/build/mkNixos.nix) [system]
     ├─ cfg.repoPath                     │   ├─ modules/nixos (font, keyboard)
     └─ cfg.scan                         │   ├─ modules/vm/* (detect, runtime, profile)
        ├─ domains (discovered)           │   ├─ capabilities from profiles
        ├─ themes (themesLib)             │   ├─ local/hardware.nix (optional)
        ├─ allToolchainPackages           │   └─ home-manager integration
        └─ treesitter (grammar builder)   └─ checks (from checks/default.nix)
```

The key improvement over the old architecture: a single `cfg` object flows through the entire pipeline, with all configuration resolved early by `lib/read-config.nix`. No host scanning, no `.env` file parsing, no inline host config loading in each builder.

## Flake Outputs

`/lib/flake/outputs.nix` produces all flake outputs from the `cfg` object and resolved `profiles`:

| Output | Description |
|--------|-------------|
| `homeConfigurations.current` | Primary home-manager config — activated by `home-manager switch --flake .#joao` |
| `nixosConfigurations.current` | Primary NixOS config — activated by `nixos-rebuild switch --flake .#current` |
| `packages.${system}.angst` | Shell script (`angst render`/`angst watch`/`angst passwd`) for hot-reload and password management |
| `packages.${system}.vm-cli` | VM CLI tool (wrapped with environment) |
| `packages.${system}.vm-run` | VM run script that auto-collects SSH keys, validates them, deduplicates, writes to `$XDG_STATE_HOME/vm/keys`, and forwards SSH port 2222 |
| `packages.${system}.res` | Shell function wrapping `nix run --impure --refresh`, exporting env vars from config |
| `packages.${system}.shell` | Standalone dev shell CLI binary |
| `devShells.${system}.*` | `safe` (neovim + parsers + LSPs) and `dev` (safe + Rust + QEMU + tools) |
| `apps.${system}.*` | Convenience apps: `check`, `lint-themes`, `lint-desktop`, `lint-shell`, `analyze`, `ssh`, etc. |
| `checks.${system}.*` | Build-time validation: theme linting, config rendering, override tests |

**Angst password** (`angst passwd` in `scripts/angst.sh`): interactively hashes a password via `mkpasswd` and writes `PASSWORD=<sha-512-hash>` to `local/config.nix`.

**Dev shells**: `safe` (neovim + parsers + LSPs + formatters) and `dev` (safe + Rust/QEMU/tools). Dev shell hook auto-initializes SSH agent and loads keys.

**res() wrapper**: Shell function wrapping `nix run --impure --refresh`, defined in `lib/flake/devshell.nix`.

**allToolchainPackages/allGrammars**: Aggregated from all 22 toolchains by `lib/read-config.nix` (based on `cfg.toolchains` filter).

**Tree-sitter**: Tree-sitter parser handling for cross-glibc compatibility, built by `lib/treesitter.nix` using grammars from toolchains.

## Source Map

| File | Role |
|------|------|
| `/flake.nix` | Root orchestration (30 lines, delegates to outputs.nix) |
| `/lib/read-config.nix` | Loads `local/config.nix` and produces unified `cfg` object |
| `/lib/build/mkHome.nix` | Home-manager profile constructor (cfg-based) |
| `/lib/build/mkNixos.nix` | NixOS system constructor (replaces mkHost.nix) |
| `/lib/flake/outputs.nix` | All flake outputs: home configs, NixOS configs, packages, dev shells, apps, checks |
| `/lib/flake/devshell.nix` | Dev shell definitions (safe, dev) with SSH agent init |
| `/lib/render.nix` | Theme rendering engine (`renderDomainOutputsFor`, `renderDomainOutputFor`) |
| `/profiles/default.nix` | Profile resolution: mkDomainEnable, mkCap, profileMap (5 profiles) |
| `/profiles/base.nix` | Base profile: core domains + capabilities |
| `/profiles/desktop.nix` | Desktop profile: i3, rofi, ghostty, graphical/audio |
| `/profiles/development.nix` | Development profile: agents, sqlit, posting |
| `/profiles/server.nix` | Server profile: SSH only |
| `/profiles/vm.nix` | VM profile: detection, runtime, SSH |
| `/modules/home/default.nix` | Base home-manager module (username, homeDirectory, fonts) |
| `/modules/home/domain.nix` | Domain framework integration for home-manager |
| `/modules/home/treesitter.nix` | Tree-sitter parser setup in home-manager |
| `/modules/home/themeModule.nix` | Theme option definition for home-manager |
| `/modules/nixos/default.nix` | Base NixOS module (keyboard layout, font) |
| `/modules/nixos/font.nix` | Global monospace font option and installation |
| `/modules/vm/*.nix` | VM detection, profile, boot, host-mount, specialisation (7 files) |
| `/capabilities/*.nix` | System feature modules (9 files) |
| `/checks/default.nix` | Check suite assembly |
| `/checks/theme/` | Theme validation checks (7 files) |
| `/local/config.nix.example` | Template for the configuration file |

## Change Guidance

### Modifying the flake structure
- **`/flake.nix`** — Root orchestration: defines inputs, loads `read-config.nix`, builds profiles, delegates to `outputs.nix`. Gate for adding new flake inputs (e.g., a new local Rust tool).
- **`/lib/flake/outputs.nix`** — Main flake outputs: home configs, NixOS configs, checks, packages, apps, dev shells. Wire new packages or checks here.
- **`/lib/flake/devshell.nix`** — Dev shell definitions. Add new shell variants or modify SSH agent/`res()` behavior here.
- **`/checks/default.nix`** — Check suite assembly.

### Modifying the build system
- **`/lib/build/mkHome.nix`** — Core home-manager profile builder. Passes `themesLib`, `theme`, `userConfig`, `monitors`, `hostname`, `repoPath` as `extraSpecialArgs`. Adding a new `extraSpecialArgs` key here propagates to all domain `render.nix` functions.
- **`/lib/build/mkNixos.nix`** — NixOS system builder (replaces old `mkHost.nix`). Wires home-manager into NixOS, imports VM detection modules, sets up password. Passes matching `specialArgs` to both NixOS and home-manager.
- **`/lib/read-config.nix`** — Loads `local/config.nix` and produces the `cfg` object. Adding a new config field requires updating both the read function and the consumers that destructure `cfg`.

### Modifying the configuration system
- **`/local/config.nix`** — Single machine identity file (gitignored). Add new top-level keys here when creating new config dimensions.
- **`/lib/read-config.nix`** — Handles defaults and fallback logic. Keep defaults sensible so new machines work without editing config.
- **`/local/config.nix.example`** — Template. Document any new keys by adding them here with comments.
- **Rust consumers** — `tools/vm/crates/vm-cli/src/runner/vm.rs` and `tools/shell/src/runner.rs` both implement config reading independently. Keep parsing consistent with the Nix-side `read-config.nix`.

### Modifying virtualization
- **Detection chain**: `modules/vm/detect.nix` sets `angst.isQemuVm` → `modules/vm/is-qemu-vm.nix` checks flake path → `modules/vm/runtime.nix` adjusts bootloader → `modules/vm/vm-profile.nix` applies full VM config.
- **To change VM resources**: Edit `modules/vm/vm-variant.nix` (vCPUs, RAM, disk).
- **To change 9p mounts or display**: Edit `modules/vm/vm-profile.nix`.
- **Testing VM detection**: The `isQemuVm` option is available at `nix eval` time for any host.

### Common pitfalls
- Capabilities are **enabled through profiles** — each profile uses `mkCap` which imports the capability and enables it. Adding a new capability file in `/capabilities/` requires adding it to the profile that should use it.
- The VM detection system assumes the flake path starts with `/host/` when running inside QEMU (from the 9p host mount). This can be affected by changes to the mount path in `modules/vm/vm-profile.nix`.
