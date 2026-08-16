# Tools

angst ships three CLI tools and an MCP server for VM management: the **angst** shell CLI, the **shell** environment switcher (Rust), and the **vm** lifecycle tool (Rust workspace). All are wired as flake outputs; `angst`, `shell`, and `vm` are also installed into home profiles by `lib/build/mkHome.nix`.

## angst CLI (`scripts/angst.sh`)

A bash script packaged via `pkgs.writeShellApplication` (runtime inputs: coreutils, findutils, git, nix, watchexec, jq, sops, age, openssl, openssh, diffutils). Exposed as `apps.angst`, `apps.render`, `apps.watch` and the `angst` package.

```
angst bootstrap-secrets [--host HOST]
angst render [--repo PATH] [--host HOST] [--theme THEME] [--reload|--no-reload]
angst watch  [--repo PATH] [--host HOST] [--theme THEME]
angst projects <add|sync|status|capture|edit-env|rm> ...
angst ssh-key <generate|verify> --scope personal|work
```

- **`render`** — determines repo root (`--repo`/git/`pwd`), host (`--host`, default `NIX_DEFAULT_TARGET_HOST`/`ANGST_HOST`/`nixos`), theme (default from the host decl via `nix eval`), batch-evals `.#lib.renderDomainOutputsFor`, writes rendered domain configs, syncs per-dir `.gitignore`, and optionally reloads i3 (`--reload`, default on; requires `i3-msg` + `I3SOCK`).
- **`watch`** — wraps render with `watchexec` on `themes/`, `domains/`, `hosts/` for hot-reload.
- **`bootstrap-secrets`** — interactive master-password bootstrap: reads password twice (never echoed), writes it into `hosts/<domain>/<host>/secrets.yaml` via sops, and writes the `mkpasswd -m sha-512` hash into the host's `password` field. Requires `sops` and `mkpasswd` on PATH. See [Secrets](secrets.md).
- **`projects`** — manages the dev-project store across three layers (`runtime/angst-projects.sh`, shared with the home-manager `angst-projects-sync` wrapper): a committed **repo store** (`projects/`, sops-encrypted), a decrypted **working store** (`~/.secrets/angst/projects`, `ANGST_PROJECTS_STORE` overrides), and clones at `~/projects`. All subcommands take the **real name** and resolve the opaque id within the working store (both scopes; names unique store-wide). Scope key selection: personal → `~/.config/sops/age/keys.txt`, work → `~/.config/sops/age/work-keys.txt` (`SOPS_*_AGE_KEY_FILE` overrides).

  | Subcommand | Behavior |
  |---|---|
  | `add <name> <repo> [--scope work\|personal]` | Random opaque-id folder + plaintext metadata/env in the working store (default scope `personal`); rejects duplicate names |
  | `sync` | Clone-if-missing into `~/projects/<name>` (no auto-pull, no hooks) + hash-tracked `.env` materialize/refresh from the working store; stale local `.env` → redacted diff + exit non-zero; missing key/repo/network → warn + exit 0. Filters to the host's declared ids when `ANGST_PROJECTS_ONLY` is set (wrapper: `projects = [...]` in the host decl; unset = CLI syncs all) |
  | `status` | Table (scope, id, name, repo, env status: `ok`/`store-changed`/`STALE`/`missing`/`no clone`) + `.env.example` var drift |
  | `capture <name>` | Copy current `~/projects/<name>/.env` → working store (then `export` to share) |
  | `edit-env <name>` | Edit working-store env → `$EDITOR` → resync clone if in sync (then `export` to share) |
  | `import [--all]` | Decrypt repo store → working store (seed); missing working entries only, unless `--all` |
  | `export [--all]` | Encrypt working store → repo store — the **only** writer of the repo store; remember to commit |
  | `rm <name>` | Remove from working store + repo store + sidecar |

  See [Secrets — Project store](secrets.md#project-store) for the sops/key flow and [Domains](domains.md#gitprojects--encrypted-project-store) for the domain.
- **`ssh-key`** — manages the shared, scope-isolated SSH keys in `secrets/ssh/` (age-encrypted at rest, one key per scope, provisioned to every host at boot). `generate` derives the recipient from the scope age key (`age-keygen -y`), writes `.age` + `.pub` from the same keypair, and prints where to authorize the public key; `verify` decrypts `.age` locally and cross-checks the committed `.pub`. See [Secrets — Shared SSH keys](secrets.md#shared-ssh-keys-secretsssh).

There is **no** `angst passwd` (old wiki/README claim); password handling happens through `bootstrap-secrets`.

## shell CLI (`tools/shell`, Rust)

A standalone binary (clap; no nix at runtime) that switches between the flake's dev environments:

- Subcommands: `dev`, `safe` (see `src/commands.rs`).
- `src/runner.rs::enter()` reads `SHELL_DEV_PATH`/`SHELL_SAFE_PATH` (injected by the nix-built wrapper; errors if unset), prepends the env path to `PATH`, sets `IN_NIX_SHELL`/`SHELL_MODE`/`ORIGINAL_SHELL`, optionally execs `SHELL_DEV_ENTRY`, then execs the host shell (`SHELL_ENABLED_SHELLS` or `$SHELL`).
- Symlinks tree-sitter parsers/queries from `SHELL_TS_PARSERS`/`SHELL_TS_QUERIES` into `~/.local/share/tree-sitter/`.
- Built by `rustPlatform.buildRustPackage`; exposes `mkOutputs` consumed by the main flake (`inputs.shell`).

Usage: `nix run .#shell -- dev`, or `nix profile install .#shell` then `shell dev`.

## vm tool (`tools/vm`, Rust workspace)

Multi-crate workspace — `vm-core` (config/SSH/shared-dir/runner plumbing), `vm-cli` (CLI + runner), `vm-mcp` (MCP server) — integrated as `inputs.vm`; `vmOutputs = inputs.vm.mkOutputs self` in `lib/flake/outputs.nix`. Exposed as the `vm-cli`/`vm` package and the `vm` app (`nix run .#vm`).

### Commands (`crates/vm-cli/src/commands.rs` + `runner/vm.rs`)

| Command | Purpose |
|---|---|
| `vm start [--headless]` | Validate `vm` profile on the target host, kill stale QEMU, build `.#nixosConfigurations.<host>.config.system.build.vm` if needed, launch, poll SSH up to 300s |
| `vm stop` / `vm restart [--headless]` | Stop / restart the VM |
| `vm status` / `vm health` | QEMU process, hostfwd, port 2222, SSH reachability |
| `vm logs [-n]` | Tail VM logs |
| `vm ssh [--auto-start] [--tty] [-- args]` | SSH into the guest (port 2222 → guest 22) |
| `vm exec -- cmd` | Run a command inside the guest |
| `vm copy-to` / `vm copy-from` | SCP files between host and guest |
| `vm mcp start\|stop\|restart\|status\|logs\|run-server [--port 8765]` | Manage the MCP server process |

> ⚠️ **Historical note:** an old README claimed `snapshot`/`restore`/`list`/`info` subcommands — they do not (and never did) exist. The command set above is the current one (verified against `crates/vm-cli/src/commands.rs`); don't add doc references to them.

### Behavior details

- **Headless**: `--headless` flag or auto when `DISPLAY` is unset (CI-friendly). `-display gtk` for interactive use.
- **SSH**: `SshEngine` connects to `127.0.0.1:2222` (hostfwd `tcp::2222-:22`), authenticating with the host's provisioned shared key (`~/.ssh/id_ed25519` by default, overridable via `VM_SSH_IDENTITY`) via `userauth_pubkey_file` — no ssh-agent, no agent forwarding.
- **Shared dir**: `vm start` prepares `$XDG_STATE_HOME/vm/keys/<host>` with copies of the host age keys only (`age-keys.txt`, optional `work-keys.txt`), passes it to the runner as `SHARED_DIR` (mounted at `/tmp/shared`). No host SSH keys or agent material crosses into the guest; inbound access is the declarative `authorized_keys` baked from `secrets/ssh/*.pub` in `modules/vm/vm-profile.nix`. The runner is spawned directly (`result/bin/run-<host>-vm`) with `ANGST_REPO`/`NIX_DISK_IMAGE`/`QEMU_NET_OPTS`/`QEMU_OPTS` env.
- **MCP server** (`crates/vm-mcp`): axum HTTP server on `127.0.0.1:8765` with `/mcp` (JSON-RPC MCP `2025-03-26`) and `/health`. Tools: `vm_exec`, `vm_status`, `vm_restart`. Managed as a background service via `VmProcessController` (`vm mcp …`). AI agents (e.g. OpenCode) can drive the VM through this.

### justfile shortcuts

```bash
just vm              # NIX_DEFAULT_TARGET_HOST=vm nix shell ./tools/vm#wrapped -c vm start
just vm-ssh          # NIX_DEFAULT_TARGET_HOST=vm nix shell ./tools/vm#wrapped -c vm ssh --auto-start
```

## Analysis script (`scripts/analyze_flake/`)

Python module that walks the flake and generates `analysis.md` (repo-structure report). Run with `just analyze` or `nix run .#analyze` / `nix run .#analyze-to-file`. The committed `analysis.md` is a stale generated artifact (predates the hosts refactor); regenerate rather than hand-edit.

## Integration Points

- `tools/vm` and `tools/shell` are **local flake inputs** (`flake.nix`) whose `mkOutputs` produce the packages/apps used across `outputs.nix`, `devshell.nix`, and `mkHome.nix`.
- The `ssh` app (`nix run .#ssh`) deploys the representative host's home activation package (`nix build .#homeConfigurations.<user>.activationPackage` → `./result/activate` → `nix-collect-garbage -d`); target overridable via `NIX_DEFAULT_TARGET_HOST`.
- All three tools land in `home.packages` (`mkHome.nix`) so they exist inside managed machines and the VM.
