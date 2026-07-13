# Architecture

angst is structured as a Nix flake with a clear separation of concerns: machine descriptors (hosts), system features (capabilities), user-space configs (domains), a unified theme system, and supporting build infrastructure.

## Flake Structure

The root `flake.nix` (`/flake.nix`) orchestrates everything:

```
inputs:
  nixpkgs           (nixos-unstable)
  home-manager      (nix-community/home-manager)
  vm                (./tools/vm, local flake)
  shell             (./tools/shell, local flake)

outputs:
  nixosConfigurations.*   -> mkHost (for each host in /hosts/)
  homeConfigurations.*    -> mkHome (for each host)
  packages.*              -> { angst, shell, vm, vm-run, ... }
  devShells.*             -> { safe, dev }
  checks.*                -> lint-themes, lint-desktop, lint-shell, ...
  apps.*                  -> { check, lint-themes, lint-desktop, ... }
```

The flake first scans hosts (`/lib/build/scanHosts.nix`), then builds domain lib and home lib, and finally constructs NixOS and home-manager configurations for each host.

## Hosts — Pure-Data Machine Descriptors

Each `/hosts/<name>/` directory contains:

| File | Purpose |
|------|---------|
| `default.nix` | Attribute set with `system`, `theme`, `user`, `monitors`, etc. — no logic |
| `configuration.nix` | NixOS module: imports hardware, capabilities, sets hostname, GPU drivers |
| `hardware.nix` | Hardware-specific config (drives, kernel modules, boot) |
| `home.nix` | Home-manager module: enables domains, sets desktop preferences |
| `user.nix` | **Optional** — user definition (username, home directory, SSH keys); used by `generic` host |

**Hosts are pure data** — `default.nix` exports only an attrset consumed by `mkHost.nix` and `mkHome.nix`. Adding a new host is just creating a new directory with these files.

- **personal** (`/hosts/personal/`): Physical workstation, AMD GPU, dual monitor, i3 WM
- **generic** (`/hosts/generic/`): Default fallback host with `user` as the default user, systemd-boot, US layout, UTC timezone, and audio/graphical/ssh/clipboard capabilities enabled. The `/boot` mount is conditionally skipped inside QEMU VMs. Used as the default target for development shells (`NIX_DEFAULT_TARGET_HOST=generic`).
- **ssh** (`/hosts/ssh/`): Headless server, no graphical stack, nushell, opencode overlay

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

Capabilities are **unconditionally imported** into every NixOS config. Internal conditionals gate the actual service enablement. The full capability set for all hosts comes from `/common/capabilities.nix` (fstrim, zramSwap, network, git, search, monitoring, container).

## Build System

### mkHome.nix (`/lib/build/mkHome.nix`)

Constructs a home-manager configuration for a host:

1. Loads host config to get `system`, `theme`, `user`, `monitors`
2. Imports `themesLib` (`/themes/default.nix`) and `domainsLib` (`/lib/domains/default.nix`)
3. Generates home-manager modules from all domain entries
4. Injects `themesLib`, `hostTheme`, `userConfig`, `monitors` as `extraSpecialArgs`
5. Optionally includes the VM and shell tools based on host config flags

**User env integration**: Resolves `user.env` from the repo root (or `~/proj/angst/user.env`). Priority chain: `ANGST_USERNAME` env var > `user.env.USERNAME` > `hostConfig.user.username`. Theme follows a similar chain: `ANGST_THEME` env var > `user.env.THEME` > `hostConfig.theme` > `themesLib.default`. The parsed `userEnv` attrset is passed as `extraSpecialArgs` for consumption by any module.

### mkHost.nix (`/lib/build/mkHost.nix`)

Constructs a full NixOS system configuration for a host:

1. Loads host config and constructs home-manager profile via `mkHomeProfile`
2. Imports capabilities (all discovered from `/capabilities/`)
3. Generates NixOS domain modules from domains with `nixos.nix`
4. Wires home-manager into NixOS via `home-manager.nixosModules`

**User env integration**: Same user env search strategy as `mkHome.nix`. Passes `userEnv`, `userConfig`, `theme`, `hostname`, `capabilities`, `monitors`, `repoPath` as `specialArgs` to NixOS modules. Username and theme resolution follow the same priority chain (env > user.env > host config > default).

### scanHosts.nix (`/lib/build/scanHosts.nix`)

Reads `/hosts/` directory and returns all subdirectory names (hostnames). Used to auto-register all hosts in the flake outputs.

## User Env System

A `user.env` file at the repository root provides runtime overrides that flow into both build-time and runtime systems, allowing per-machine customisation without modifying checked-in Nix files.

### File Format

```
HOST=generic
USERNAME=user
PASSWORD=$y$j9T$...  (sha-512 hash, generated by `angst passwd`)
THEME=monochrome
```

Blank lines and lines starting with `#` are ignored. Values are parsed by `/lib/parseEnv.nix` at build time and by the Rust CLI tools (`read_env_value()`) at runtime.

### Resolution Priority

Every consumer follows the same chain: **environment variable** > **user.env value** > **host config default** > **fallback constant**. This means you can override anything without editing Nix files:

| Setting | Env Var | user.env key | Host Config | Fallback |
|---------|---------|-------------|-------------|----------|
| Host target | `ANGST_HOST` / `NIX_TARGET_HOST` | `HOST` | — | `generic` |
| Username | `ANGST_USERNAME` | `USERNAME` | `user.username` | — |
| Theme | `ANGST_THEME` | `THEME` | `theme` attr | `monochrome` |
| Password | `ANGST_PASSWORD` | `PASSWORD` | — | `null` |

### Consumption Points

| Context | How user.env is read | Files |
|---------|---------------------|-------|
| Nix build-time | `builtins.readFile` via `parseEnv.nix` | `mkHome.nix`, `mkHost.nix`, `lib/nixos/default.nix` |
| VM CLI runtime | `read_env_value()` in Rust | `tools/vm/crates/vm-cli/src/runner/vm.rs` |
| VM core config | `VmConfig` struct reads env vars | `tools/vm/crates/vm-core/src/config.rs` |
| Shell CLI runtime | `read_env_value()` in Rust | `tools/shell/src/runner.rs` |
| Password setup | `angst passwd` writes PASSWORD to user.env | `scripts/angst.sh` |

## Virtualization / VM Detection

The repository has sophisticated VM support for development:

1. **Detection** (`/lib/virtualisation/detect.nix`, `is-qemu-vm.nix`): Sets `angst.isQemuVm` based on whether the flake path starts with `/host` (indicating a 9p host mount from QEMU)
2. **VM Profile** (`vm-profile.nix`): 9p filesystem mounts, SPICE vdagent, SSH key injection, monitor override
3. **Boot** (`runtime.nix`): `systemd-boot` on bare metal, grub disabled in VM
4. **Host Mount** (`host-mount.nix`): Symlinks `/home/joao/.config/angst` to the host 9p path for live editing
5. **Specialisation** (`specialisation.nix`): Bootable specialisation entry for VM mode without rebuild-vm
6. **vmVariant** (`vm-variant.nix`): QEMU VM config via `virtualisation.vmVariant` (4 vCPUs, 4GiB RAM, 16GB disk)

## Data Flow

```
user.env                            hosts/<name>/default.nix
  ├─ HOST, USERNAME, THEME, PASSWORD  ├─ system, theme, user, monitors
  ▼                                    ▼
lib/parseEnv.nix                   lib/build/mkHome.nix
  └─ userEnv attrset                  ├─ themesLib (from /themes/default.nix)
                                      ├─ domainsLib (from /lib/domains/default.nix)
                                      ├─ injects theme, userConfig, monitors, userEnv as specialArgs
                                      ▼
                                    home-manager configuration
                                      ├─ /hosts/<name>/home.nix (domain enables)
                                      ├─ /common/home.nix (shared domain enables + toolchains)
                                      ├─ themeModule.nix (theme option)
                                      ├─ domain modules (auto-generated from domain scan)
                                      │   ├─ renders theme-aware configs via render.nix
                                      │   ├─ installs packages, sets up XDG symlinks
                                      │   └─ optionally runs custom module.nix / nixos.nix
                                      └─ vm/shell tool packages (conditional)
```

## Shared Flake Outputs

`/lib/flake/shared.nix` collects cross-cutting outputs:

- **angst CLI** — Shell script (`angst render`/`angst watch`/`angst passwd`) for hot-reload and password management
- **angst password** — `angst passwd` interactively hashes a password via `mkpasswd` and writes `PASSWORD=<sha-512-hash>` to `user.env`
- **Dev shells** — `safe` (neovim + parsers + LSPs + formatters) and `dev` (safe + Rust/QEMU/tools). Dev shell auto-initializes SSH agent and loads keys.
- **VM run shim** — `vm-run` script auto-collects SSH public keys (from `ssh-agent` and `~/.ssh/*.pub`), validates format, deduplicates them, writes them to `$XDG_STATE_HOME/vm/keys/$TARGET_HOST/authorized_keys`, and forwards SSH port 2222
- **res() wrapper** — Shell function wrapping `nix run --impure --refresh` that exports `ANGST_PASSWORD`, `ANGST_USERNAME`, `ANGST_THEME`, `ANGST_HOST` from `user.env`
- **allToolchainPackages/allGrammars** — Aggregated from all 19 toolchains
- **treesitter** — Tree-sitter parser handling for cross-glibc compatibility

## Source Map

| File | Role |
|------|------|
| `/flake.nix` | Root orchestration |
| `/lib/build/scanHosts.nix` | Auto-discovers hosts/ directories |
| `/lib/build/mkHome.nix` | Home-manager profile constructor (user env aware) |
| `/lib/build/mkHost.nix` | NixOS system constructor (user env aware) |
| `/lib/flake/default.nix` | Flake outputs: domain renders, checks, dev shells |
| `/lib/flake/shared.nix` | Shared infra: angst CLI, shells, toolchains, treesitter, vm-run shim, res() wrapper |
| `/lib/parseEnv.nix` | Parses `user.env` into Nix attrs at build time |
| `/lib/virtualisation/*.nix` | VM detection, profile, boot, host-mount, specialisation |
| `/lib/nixos/default.nix` | Base NixOS module (password resolution from user env) |
| `/common/home.nix` | Shared home-manager imports |
| `/common/capabilities.nix` | Shared NixOS capability enables |
| `/common/user.nix` | User definition (joao) |
| `/user.env.example` | Template for the user env configuration file |

## Change Guidance

### Modifying the flake structure
- **`/flake.nix`** — Root orchestration: defines inputs, scans hosts, builds domain lib and home lib, constructs `nixosConfigurations` and `homeConfigurations`. Gate for adding new flake inputs.
- **`/lib/flake/default.nix`** — Main flake outputs: home configs, checks, packages, apps, dev shells. Wire new packages or checks here.
- **`/lib/flake/shared.nix`** — Cross-cutting utilities: angst CLI, toolchain aggregation, tree-sitter, dev shell PATH construction, vm-run shim, password handling, res() wrapper. Change dev shell contents, SSH key provisioning, or password utilities here.
- **`/lib/flake/homeConfigurations.nix`** — Home-manager configuration generation per host.
- **`/lib/flake/checks.nix`** — Check suite assembly.

### Modifying the build system
- **`/lib/build/mkHome.nix`** — Core home-manager profile builder. Passes `themesLib`, `hostTheme`, `userConfig`, `monitors`, and now `userEnv` as `extraSpecialArgs` to all modules. Adding a new `extraSpecialArgs` key here propagates to all domain `render.nix` functions. User env resolution follows the chain: env var > `user.env` file > host config > default.
- **`/lib/build/mkHost.nix`** — NixOS system builder. Wires home-manager into NixOS, imports capabilities, generates NixOS domain modules. Passes `userEnv`, `userConfig`, `theme`, `hostname`, `capabilities`, `monitors`, `repoPath` as `specialArgs`.
- **`/lib/build/scanHosts.nix`** — Auto-discovers hosts by reading `/hosts/` directory. Adding a host directory here automatically includes it.

### Modifying the user env system
- **`/lib/parseEnv.nix`** — Reads and parses `user.env`. Changes to the parsing logic affect all build-time consumers (mkHome.nix, mkHost.nix, lib/nixos/default.nix).
- **`/user.env.example`** — Template. Document any new keys by adding them here with comments.
- **Rust consumers** — `tools/vm/crates/vm-cli/src/runner/vm.rs` and `tools/shell/src/runner.rs` both implement `read_env_value()` independently. Keep parsing consistent with the Nix-side `parseEnv.nix`.
- **Password flow** — `scripts/angst.sh` (`angst passwd`) writes `PASSWORD=<hash>` to `user.env`. `lib/nixos/default.nix` reads it at build time. If you add new secret-like fields, ensure the angst.sh write and nixos read stay in sync.

### Modifying virtualisation
- **Detection chain**: `/lib/virtualisation/detect.nix` sets `angst.isQemuVm` → `/lib/virtualisation/is-qemu-vm.nix` checks flake path → `/lib/virtualisation/runtime.nix` adjusts bootloader → `/lib/virtualisation/vm-profile.nix` applies full VM config.
- **To change VM resources**: Edit `/lib/virtualisation/vm-variant.nix` (vCPUs, RAM, disk).
- **To change 9p mounts or display**: Edit `/lib/virtualisation/vm-profile.nix`.
- **Testing VM detection**: The `isQemuVm` option is available at `nix eval` time for any host.

### Common pitfalls
- Capabilities are **unconditionally imported** into every NixOS config; enabling is gated by internal conditionals. A new capability file in `/capabilities/` is auto-discovered and imported everywhere.
- The VM detection system assumes the flake path starts with `/host/` when running inside QEMU (from the 9p host mount). This can be affected by changes to the mount path in `vm-profile.nix`.
