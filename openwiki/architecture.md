# Architecture

angst is a Nix flake that turns **pure data host declarations** (`hosts/<domain>/<hostname>/default.nix`) into NixOS systems, home-manager profiles, packages, dev shells, apps, and checks. The flake itself is a thin orchestration layer; all machinery lives in `lib/`.

## Flake Inputs and Outputs

`flake.nix` declares inputs, all pinned together on `nixos-unstable`:

| Input | Source | Role |
|---|---|---|
| `nixpkgs` | `github:nixos/nixpkgs/nixos-unstable` | Base packages |
| `home-manager` | `nix-community/home-manager` (follows nixpkgs) | User profiles |
| `sops-nix` | `Mic92/sops-nix` (follows nixpkgs) | Secret decryption |
| `impermanence` | `nix-community/impermanence` | `/persist` state |
| `vm` | `./tools/vm` (local flake, follows nixpkgs) | Rust VM toolchain + `mkOutputs` |
| `shell` | `./tools/shell` (local flake, follows nixpkgs) | Rust shell switcher + `mkOutputs` |

Outputs flow:

1. `lib/discover.nix ./hosts` — recursively finds host decls (`{hostname, domain, dir}`). A directory containing `default.nix` is a host; a directory of host directories is a domain (e.g. `personal/` contains `mint/`, `nixos/`).
2. For each entry, `lib/resolve.nix` imports the decl and normalizes it into a `host` object: defaults (`system`, `hostname`, `username`, `theme = "monochrome"`, `profiles = ["base"]`, a default "changeme" password hash, `type = "nixos"`), plus `scan` (domains via `lib/domains/scan.nix`, themes, tree-sitter grammar builder) and resolved `toolchainModules` (validated against `/toolchains/`, `"*"` or list).
3. `lib/flake/outputs.nix` — for every host builds a `homeConfigurations.<username>` via `lib/build/mkHome.nix` and, for `type == "nixos"` hosts, a `nixosConfigurations.<hostname>` via `lib/build/mkNixos.nix`. It also emits `packages` (activation packages, `angst`, `shell`, `vm-cli`, `vm-run`, `res`, `default`), `apps` (`vm`, `shell`, `angst`, `render`, `watch`, `check`, `lint-*`, `analyze`, `ssh`), `devShells` (`safe`, `dev`, `vm`), `checks`, and `formatter` (nixfmt).

The `representative` host (first NixOS host) drives shared outputs: `default` package, dev shells, checks, and the `ssh` deploy app (`nix build .#homeConfigurations.<user>.activationPackage` → `./result/activate` → gc).

## Builders

### `lib/build/mkNixos.nix`

Assembles a `nixosSystem` from:
- the host decl's profile modules (`nixosModules`), domain system modules (`mkNixosSystemModule` over `systemEntries`), `modules/nixos` base, per-host `hardware.nix` (auto-detected next to the decl), `host.extraNixos`, session env vars;
- **always**: `sops-nix` NixOS module + `secrets.systemCore`, and the VM stack (`modules/vm/detect.nix`, `runtime.nix`, `vm-variant.nix`, `host-mount.nix`);
- **`angst-bootstrap-secrets`** systemd service (when secrets are decryptable): derives the login hash from the decrypted `masterPassword` via `mkpasswd -m sha-512`, applies it to user + root, and generates/repairs `~/.ssh/id_ed25519` with the master password as passphrase (runs before getty/display-manager);
- impermanence (when `host.persist.enable`), home-manager NixOS module wiring `secrets.homeModules` into the user, and service ordering (`home-manager-<user>` before sshd/getty; getty ordering skipped on QEMU VMs).

### `lib/build/mkHome.nix`

Assembles `homeManagerConfiguration` from:
- `modules/home` base, `themeModule`, one generated module per domain (`mkDomainModule`), profile enable modules (`hmModules`), `host.toolchainModules`, `secrets.homeModules`, plus `angst`/`shell`/`vm`/`res` tools in `home.packages`;
- `host.env` → `home.sessionVariables`, `host.extraHome` passthrough, and per-host special args (`hostname`, `monitors`, `db`, `sshAgent`, `ssh`, `shell`, `themes`, `flakeSelf`, …).

Both builders receive `themeOverride`/`shellOverride` to power the representative test configs (`<user>-theme-override-test`, `login-shell-valid`, `login-shell-invalid`) used by checks.

## Hosts and Configuration Model

There is **no** `local/config.nix` anymore: machine identity is a tracked, diffable Nix file per host. The decl shape is documented in [quickstart](quickstart.md); `lib/resolve.nix` defines every field and default. `hosts/vm/secrets.yaml` and `hosts/personal/mint/secrets.yaml` hold the sops-encrypted secrets; `hosts/personal/nixos/` currently has none.

> The old single-file model (`local/config.nix` + `lib/read-config.nix`) was removed in the `refac/pure` → `refac/nix-managed-home` progression (mid-2026). Rationale recorded in `pure.md`: disposability and purity — machine identity as plain, diffable Nix, auto-discovered, zero ceremony (no flake.nix edits), no `--impure`/env hacks.

## Profiles and Features

`profiles/default.nix` defines a `profileMap` and resolves each host's selected profiles:

- Each profile is a **pure feature list**: `{ enable = ["category.name" ...]; }` plus an optional `modules` list for NixOS-only infrastructure (the VM stack). There is no `{ hm, nixos }` split — features declare their own sides via `home.nix`/`system.nix`, and `host.type` (`nixos` vs `home`) decides which sides are built.
- `resolve profiles` validates every feature name against the domain scan (**throws** on unknown names, build-time safety) and concatenates the selected profiles' `enable` lists + `modules`.

`lib/flake/outputs.nix` turns the resolved list into per-scope enable modules: home scope for every enabled feature (a home `enable` option always exists), system scope only for features with a `system.nix`, plus the profile's raw `modules`. Profile contents are in the [quickstart profiles table](quickstart.md#profiles).

## VM Support

The same flake builds a disposable QEMU VM per host. Stack (`modules/vm/`):

- `detect.nix` + `is-qemu-vm.nix` — internal `angst.isQemuVm` option; true when the flake is evaluated from a 9p mount (`/host…`) or the expected host-repo path exists on the guest.
- `runtime.nix` — conditional bootloader: systemd-boot/EFI only when **not** a QEMU VM; grub disabled in VMs.
- `vm-variant.nix` — `virtualisation.vmVariant`: tmpfs `/` (2G), `/persist` ext4 on `/dev/disk/by-label/nixos`, 4 cores / 4096 MB / 16G disk, SPICE + vdagent, and a 9p `sharedDirectories.angst` mount (`${ANGST_REPO:-$PWD}` → `/host/…`).
- `vm-profile.nix` — via `profiles/vm.nix`: ephemeral `/etc/ssh` tmpfs, `vm-authorized-keys` + `vm-age-key` units consuming `/tmp/shared` (SSH keys and the host age key injected from outside), `home-manager-upgrade` service.
- `host-mount.nix` — activation symlink `~/.config/angst → /host/…/angst` for **live editing** of the repo from inside the VM.
- `specialisation.nix` — defines a `specialisation.vm.configuration` but is **never imported** (dead code).

The Rust `tools/vm` CLI drives the lifecycle (build/start/ssh/…); see [Tools](tools.md) and [Operations](operations.md).

## Impermanence

When `host.persist.enable` is true (currently `personal/nixos` and `vm`), `modules/nixos/persist.nix` enables impermanence with system dirs (`/var/log`, `/var/lib/*`, `/etc/ssh`, `/etc/machine-id`) and user dirs = `persist.homeDirs` ++ secret-derived `persistDirs` (`.config/sops`, `.secrets` when decryptable). Defaults live in `lib/resolve.nix`: `persist = { root = "/persist"; homeDirs = []; enable = false; }`.

## Dev Shells

`lib/flake/devshell.nix` builds three shells from the representative host:

- `safe` — neovim, git, deadnix, statix + toolchain packages (editing without dev tooling);
- `dev` — everything in `safe` plus the angst CLI, openssh, qemu, sops, age, gitleaks, Rust toolchain, and the VM tools (`vm` wrapped, `vm-run`, `res`); exports `VM_SSH_PORT=2222` and `NIX_DEFAULT_TARGET_HOST`, inits ssh-agent, and hooks tree-sitter.
- `vm` — `inputsFrom` the vm tool's dev shell + dev packages (Rust tooling for `tools/vm`).

## Known Staleness and Dead Code

Documented here so future agents don't chase ghosts:

- **`modules/vm/specialisation.nix`** — never imported.
- **`domains/llm/opencode/`** — contains only `config/node_modules/`, no `default.nix`; dead and would fail `scan.nix` if evaluated.
- **`analysis.md`** — generated artifact from `scripts/analyze_flake/`, stale since before the hosts refactor; regenerate with `just analyze`.
- **`lib/toolchain.nix`** is *not* dead — every `/toolchains/*.nix` file imports it as the `mkToolchain` builder.

> The README previously described the removed `local/config.nix` model, `capabilities/default.nix` auto-discovery, and non-existent VM CLI commands; it was rewritten (2026-08) to match the current hosts-driven architecture and now links to the `openwiki/` pages as the maintained reference.

## Change Guidance

- The pipeline is `hosts → discover → resolve → builders → outputs`. Start from the decl, then follow `resolve.nix` → the relevant builder in `lib/build/`.
- Adding a builder-level option usually means touching `resolve.nix` (defaults), the builder(s), and special args in both `mkNixos.nix`/`mkHome.nix`.
- After changing module wiring, run `nix flake check` (or `nixos-rebuild dry-run`-style builds via `nix build .#nixosConfigurations.ci` for a fast check-only host).
- Keep README claims in sync with code when you touch areas it documents; the wiki pages under `openwiki/` are the maintained reference.
