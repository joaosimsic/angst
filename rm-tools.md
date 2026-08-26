# Removing `tools/`: migrating the VM tool, shell switcher, and `analyze_flake` to Go

## Status

- **Proposed** — no implementation yet.
- **Scope (decided):** port **everything** in `tools/` into `runtime/`, rewritten in Go, including the VM MCP server. No parallel Rust/Python tooling remains.
- **Key finding from audit:** the VM *guest-side* lifecycle (`age-key`, `ephemeral-ssh`, `home-manager-upgrade`, `home-switch`, `nixos-switch`) **already lives in Go** (`runtime/angst/internal/vm`). The five `runtime/vm/*.nix` systemd units already call `${goAngst}/bin/angst vm …`. So the real porting surface is narrower than it looks: only the **host-side** VM workflow (`start`/`stop`/`restart`/`status`/`health`/`logs`/`ssh`/`exec`/`copy-to`/`copy-from`/`mcp`) and the `shell`/`analyze` tools remain to be brought into Go. The Rust `vm`/`shell` crates are today wired **only** as the interactive `vm`/`shell` apps, packages, devshell, and Home Manager packages.

## Why

`runtime/angst` is already the canonical CLI. Today `main.go` dispatches: `render`, `watch`, `bootstrap-master-password`, `set-password-hash`, `projects`, `ssh-key`, `login-shell`, `ssh-add-keys`, `provision-ssh-key`, `provision-app-secret`, `ftp`, `vault`, `vm`. The three `tools/` outliers are Rust/Python:

- `tools/vm` (Rust workspace) — host-side VM lifecycle + MCP server
- `tools/shell` (Rust) — dev/safe environment switcher
- `tools/analyze_flake` (Python) — repo-structure report generator

Consolidating into Go removes two languages (Rust, Python) from the tooling surface (leaving **Go + Nix**) and unifies the `vm` concept, which today is split across guest-side Go (`internal/vm`) and host-side Rust (`tools/vm`). It also closes a known gap: the Nix wrapper that was supposed to inject `SHELL_*` env vars for the `shell` tool was **never actually built** — the Go port must supply it.

## Goals & non-goals

**Goals**
- Single `angst` binary (Go) owns `vm` end-to-end (guest + host + MCP).
- `angst shell dev|safe` replaces the Rust `shell` binary, with the missing env-injection wrapper supplied.
- `angst analyze` replaces `python3 -m tools.analyze_flake`, preserving the 34-section Markdown **structure and headings**. Sections that self-describe the repo (the language/LOC breakdown) will necessarily change once Rust/Python are removed, so "byte-for-byte" equality against the Python output is explicitly **not** a goal — structure preservation is.
- Zero new Go runtime dependencies; reuse `internal/cmd`, `internal/shared`, `internal/paths`, `internal/scope`.

**Non-goals**
- No behavior change to the five guest-side `vm` subcommands (already in Go).
- No protocol change to the MCP server (must remain JSON-RPC 2.0, `2025-03-26`, `POST /mcp`, `GET /mcp` (Streamable-HTTP `text/event-stream` stream), `GET /health`).
- No rewrite of the NixOS VM module (`modules/vm/vm-profile.nix`) or `runtime/vm/*.nix` systemd units beyond confirming they still resolve.

## Architecture decisions

### VM (host-side + MCP)

- **No name clash.** `vm.Run` already switches on guest subcommands; add a host branch. New host subcommands: `start`, `stop`, `restart`, `status`, `health`, `logs`, `ssh`, `exec`, `copy-to`, `copy-from`, `mcp`. Distinct strings from the existing `age-key`/`ephemeral-ssh`/`home-manager-upgrade`/`nixos-switch`/`home-switch`.
- **No new Go deps.** Shell out to system `ssh`/`scp`/`qemu`/`nix` via `internal/cmd` (`Run`/`Output`/`OutputRaw`/`Feed`). **Do not** pull in `golang.org/x/crypto/ssh` — the Rust `ssh2` dependency is dropped entirely; the Go port uses `scp`/SSH over `exec.Command`.
- **MCP server** uses stdlib `net/http` with a hand-rolled JSON-RPC 2.0 handler mirroring the Rust `vm-mcp` crate. Keep protocol version `2025-03-26`, `POST /mcp` (requests), `GET /mcp` (Streamable-HTTP `text/event-stream` stream — the existing server returns `: vm-mcp stream ready`), and `GET /health`. Listen on `127.0.0.1:8765`. **Do not** drop `GET /mcp` — the current server exposes it and Streamable-HTTP clients rely on it for server→client messages.

**State schema** (replace Rust `VmProcessController` JSON). One file per service under `VM_STATE_DIR` (`$XDG_STATE_HOME/angst/vm`):

```json
// <VM_STATE_DIR>/<service>.json   service ∈ {vm, vm-mcp}
{
  "service": "vm",
  "pid": 12345,
  "started_at": "2026-08-24T10:00:00Z",
  "host": "vm",
  "port": 2222,
  "cmd": ["result/bin/run-vm-vm", "…"],
  "log": "<VM_STATE_DIR>/logs/vm.log"
}
```

`logs/<service>.log` is the `tail -f` target (mirrors Rust `Sys::stream_logs`).

**Env vars (port from `vm-core/src/config.rs`):**

| Var | Default | Use |
|---|---|---|
| `VM_SSH_PORT` | `2222` | SSH forward port |
| `VM_SSH_USER` / `ANGST_USERNAME` | `joao` | Guest login user |
| `VM_SSH_IDENTITY` | `~/.ssh/id_ed25519` | SSH key for `ssh`/`scp` |
| `NIX_DEFAULT_TARGET_HOST` / `ANGST_HOST` | `vm` | Which NixOS VM config to build/launch |
| `ANGST_REPO` | repo root | Mounted into guest `SHARED_DIR` |
| `NIX_DISK_IMAGE` | — | QEMU disk image path |
| `XDG_STATE_HOME` | `~/.local/state` | Base for `VM_STATE_DIR` |
| `VM_STATE_DIR` | `$XDG_STATE_HOME/angst/vm` | State/log dir |
| `DISPLAY` / `WAYLAND_DISPLAY` | — | If unset → headless (`-display none`) |
| `ANGST_PASSWORD` | — | Passed to runner env |

**Runner env** (from `vm-core/src/runner.rs` `prepare()`): `SHARED_DIR`, `ANGST_REPO`, `NIX_DISK_IMAGE`, `QEMU_NET_OPTS=hostfwd=tcp::2222-:22`, and `QEMU_OPTS=-display none` when headless.

**Shared dir prep** (from `vm-core/src/shared.rs`): copy host `~/.config/age/keys.txt` and `work-keys.txt` into `VM_STATE_DIR/keys/<host>` (mounted at `/tmp/shared` in the guest). This is the sole host→guest secret injection and must match what `ageKey`/`ephemeralSsh` guest commands expect.

**`start` flow** (port `commands.rs` `start --headless`):
1. Resolve `host` from `NIX_DEFAULT_TARGET_HOST`/`ANGST_HOST` (default `vm`).
2. Validate the `vm` Nix profile exists; kill any stale QEMU (`pkill -f run-<host>-vm` guarded).
3. `nix build .#nixosConfigurations.<host>.config.system.build.vm` (via `cmd.Output`, `--no-link` optional) → `result/`.
4. Launch `result/bin/run-<host>-vm` in background; write state JSON + redirect output to `logs/vm.log`.
5. Poll SSH reachability up to ~1500s (reuse `health.go` logic).

**MCP tools** (port `vm-mcp/src/tools`): `vm_exec` (SSH exec via `ssh`), `vm_status` (active + SSH-reachable check), `vm_restart` (headless). Advertised via `tools/list`; methods `initialize`, `notifications/initialized`, `tools/list`, `tools/call`. `/health` runs `ssh … echo ok` and reports reachable.

### shell

- New `angst shell dev|safe` (package `internal/shell`, `Run(args []string) int`).
- **Supply the missing wrapper.** The Rust "nix-built wrapper" that injected `SHELL_*` env vars was never built. Add an `angstShell` `mkScript` in `runtime/default.nix` that bakes the `dev`/`safe` `mkShell` bin dirs into `SHELL_DEV_PATH`/`SHELL_SAFE_PATH`/`SHELL_DEV_ENTRY`/`SHELL_ENABLED_SHELLS`/`SHELL_TS_PARSERS`/`SHELL_TS_QUERIES` and `exec`s `angst shell "$@"`.
- **Behavior to preserve** (port `tools/shell/src/runner.rs`): read `SHELL_DEV_PATH`/`SHELL_SAFE_PATH` (required); optional `SHELL_DEV_ENTRY` (dev only); `SHELL_ENABLED_SHELLS` (else `$SHELL`/`/bin/bash`); `SHELL_TS_PARSERS`/`SHELL_TS_QUERIES` symlinked into `~/.local/share/tree-sitter`. Prepend selected path to `PATH`; set `IN_NIX_SHELL`, `name`, `SHELL_MODE`, `ORIGINAL_SHELL`; then `exec` host shell (or `SHELL_DEV_ENTRY` for `dev`).

### analyze

- New `angst analyze` (package `internal/analyze`), ports the 34-section Markdown report. Flags: `--no-eval-cost`, `--no-graph`, `-o/--output FILE` (default stdout).
- Re-point `runtime/apps/analyze.nix` and `runtime/apps/analyze-to-file.nix` to `exec angst analyze "$@"`; drop `python3` from `runtimeInputs` (keep `rg`/`git`/`deadnix`/`statix`; last two optional/graceful-degrade, matching today).
- **Section map to port** (from `tools/analyze_flake/sections/*`):
  - `overview` (1–6): overview, file-size heatmap, directory breakdown, attribute surface, config matrix, render coverage.
  - `graph` (7–9): dependency fan-in/out, module coupling graph, build depth.
  - `inventory` (10–16): duplication hotspots, hardcoded strings, domain/theme/capability/toolchain/host inventory.
  - `analysis` (17–22): option inventory, Nix idiom usage, conditional/builtins usage, complexity metrics, "interesting" complexity, error handling.
  - `quality` (23–26): dead code (deadn  ix), anti-patterns (statix), evaluation cost (`nix eval`), technical-debt score.
  - `churn` (27–28): hotspot table, stability index (git log).
  - `coverage` (29–34): theme×domain coverage, domain features, check results, rendered output sizes, growth velocity, theme token usage audit.
- **Inputs** (port `util.py`): text-based via `rg` with `RG_EXCLUDES=[!.git,!result,!tools/vm/**,!tools/shell/**]` and `Path.rglob("*.nix")`; shells out to `nix`, `git`, optional `deadnix`/`statix`. Must run from repo root (use `internal/paths.RepoRoot()`). Keep the `tools/vm`/`tools/shell` excludes — but once those dirs are deleted, drop the excludes.
- **Suggested Go layout** (`internal/analyze/`): `util.go` (rg/git/eval helpers, `findNixFiles`), `lexer.go` (minimal Nix tokenizer for option/idiom/builtins detection), `graph.go` (import graph → Mermaid), `churn.go` (git log aggregation), `sections.go` (34 `sectionN` functions returning Markdown strings), `main.go` (`Run` + flag parsing + assembly).

## New files (under `runtime/`)

| File | Purpose | Key signatures |
|---|---|---|
| `internal/vm/host.go` | `start`/`stop`/`restart`/`status`/`health`/`logs`/`ssh`/`exec`/`copy-to`/`copy-from` | `func start(args) int`, `func ssh(args) int`, `func copyTo(args) int`, `func copyFrom(args) int` |
| `internal/vm/control.go` | `VmProcessController`: JSON state, shared-dir prep, QEMU launch | `type ServiceState struct{…}`; `func (c *Controller) Start/Stop/Restart/Status(name) error` |
| `internal/vm/health.go` | qemu `pgrep`, hostfwd parse, port 2222 listen check, ssh-reachable | `func checkHealth() Health` |
| `internal/vm/mcp.go` | `vm mcp start\|stop\|restart\|status\|logs\|run-server`; JSON-RPC 2.0 handler; tools `vm_exec`/`vm_status`/`vm_restart`; `POST /mcp` + `GET /mcp` (SSE stream) + `/health` | `func runServer(port int) error`; `func handleRPC(w, r)`; `func handleStream(w, r)` |
| `internal/shell/shell.go` | `dev`/`safe`: env read, PATH prepend, tree-sitter symlink, exec host shell | `func Run(args) int`; `func enter(mode string) error` |
| `internal/analyze/*.go` | Port of 34 Python sections (util + Nix lexer + graph + churn) | `func Run(args) int`; `func sectionN(...) string` |
| `runtime/default.nix` | Add `vmTool` (makeWrapper around `goAngst`, full PATH: qemu/openssh/coreutils/procps/bash/nix), `angstShell` wrapper; repoint analyze apps; export new outputs | — |
| `runtime/apps/analyze.nix`, `runtime/apps/analyze-to-file.nix` | `exec angst analyze "$@"` | — |

**`goAngst` PATH extension:** the current `makeWrapper` only prefixes `age`+`openssh`. The host VM workflow needs `qemu`/`openssh`/`coreutils`/`procps`/`bash`/`nix` on `PATH` (the Rust `wrapped` binary's job). Add a dedicated `vmTool` wrapper (or extend `goAngst`) so `angst vm start` can find `qemu-system-x86_64`, `pgrep`, etc.

## Modified files (with intent)

- `runtime/angst/main.go` — add `case "shell": return shell.Run(args)` and `case "analyze": return analyze.Run(args)`; `internal/vm.Run` gains a host/`mcp` dispatch branch (no guest command names changed).
- `flake.nix` — delete `vm` (`flake.nix:12-15`) and `shell` (`flake.nix:17-20`) input blocks.
- `lib/flake/context.nix` — remove `vmOutputs`/`shellOutputs`/`vmTool`/`shellTool` (`context.nix:41-44,84-85,114,202-205`); source `vm`/`shell` from `runtime` outputs.
- `lib/flake/apps.nix` — re-point `vm` app (`apps.nix:22`) and `shell` app (`apps.nix:23`) to `runtime` outputs (e.g. `runtime.vmTool` / `runtime.angstShell`).
- `lib/flake/packages.nix` — remove `vmOutputs`/`shellTool` imports (`packages.nix:11-12`); drop `vm-cli`/`vm`/`shell` Rust packages (`packages.nix:32-34`) or re-point to `runtime`.
- `lib/flake/devshell.nix` — remove `inputs.vm.devShells` (`devshell.nix:69`) and `inputs.vm.defaultVmHost` (`devshell.nix:22`); replace the devshell `PATH` injection `vmOutputs.packages.${host.system}.wrapped` (`devshell.nix:45`) with `runtime.vmTool`; define a local `defaultVmHost = "vm"`; drop the `CARGO_BUILD_TARGET_DIR` hook in `runtime/devshell-hook.nix:8` (no more in-tree Rust build).
- `lib/build/mkHome.nix` — remove `vmTool`/`shellTool` from args (`mkHome.nix:6-7`) and `home.packages` (`mkHome.nix:79-80`); replace with runtime outputs.
- `README.md` — update the `tools/vm`, `tools/shell`, `tools.analyze_flake` references (lines 21, 45-47, 260, 262, 325) to describe the Go `angst vm`/`angst shell`/`angst analyze`; remove the Rust/Python toolchain description (including the `vm` MCP server and `tools/vm#wrapped` invocations).
- `justfile` — `vm`/`vm-ssh` (`justfile:62-66`) → `nix run .#vm -- start` / `nix run .#vm -- ssh --auto-start`; `analyze` (`justfile:25-26`) → `nix run .#analyze -- --output analysis.md`.

**Rewiring checklist (verified against current tree):**

| Wiring | File:line | Action |
|---|---|---|
| Flake inputs `vm`/`shell` | `flake.nix:12-20` | Delete |
| Outputs sourcing | `context.nix:41-44,84-85,114,202-205` | Remove + source from `runtime` |
| `vm`/`shell` apps | `apps.nix:22-23` | Re-point to `runtime` |
| `vm`/`shell` imports + `vm-cli`/`vm`/`shell` packages | `packages.nix:11-12,32-34` | Remove imports + re-point/remove |
| Devshell `defaultVmHost` + vm `PATH` injection | `devshell.nix:22,45,69` | Local `defaultVmHost`; replace line 45 `vmOutputs...wrapped` with `runtime.vmTool`; drop `inputs.vm.devShells` |
| Home packages | `mkHome.nix:79-80` | Replace with runtime outputs |
| `vm`/`vm-ssh` just recipes | `justfile:62-66` | Re-point to `angst vm` |
| `analyze` just recipe | `justfile:25-26` | Re-point to `angst analyze` |
| analyze apps | `runtime/apps/analyze*.nix` | `exec angst analyze` |
| `README.md` | lines 21, 45-47, 260, 262, 325 | Replace `tools/vm`/`tools/shell`/`tools.analyze_flake` with Go `angst vm`/`angst shell`/`angst analyze`; drop Rust/Python toolchain description |
| `analysis.md` (golden) | repo root | Regenerate from Go port in Phase 3; will differ (language/LOC) |
| systemd VM units | `runtime/vm/*.nix` | **No change** (already Go) |

## Testing strategy

- **VM host:** Go unit tests for `control.go` state read/write and `health.go` parsing with fake QEMU/`pgrep`. A smoke test launches a throwaway build only if a VM host is configured; otherwise assert the binary parses `status`/`health` gracefully when no VM is running.
- **MCP:** add `TestMCPSmoke` hitting `POST /mcp` (`initialize`, `tools/list`, `tools/call`), `GET /mcp` (assert `text/event-stream` response), and `GET /health` against an `httptest` server; assert JSON-RPC shape + protocol `2025-03-26`. This is the contract guardrail — it must **fail** if `GET /mcp` is dropped.
- **shell:** test `enter` with a fake host shell and temp `~/.local/share/tree-sitter`; assert `PATH` prepend, symlinks, and env vars (`PATH`, `IN_NIX_SHELL`, `SHELL_MODE`, `ORIGINAL_SHELL`).
- **analyze:** **snapshot test** — run `angst analyze` on a fixed fixture repo and **regenerate** the golden `analysis.md` from the Go port (do **not** diff against the Python output — it is invalidated because the language/LOC breakdown changes). Gate eval-cost/graph/churn sections with the same `--no-*` flags; assert section count == 34, headings match, and volatile numbers (churn/eval-cost) are normalized before comparison. This is the largest-risk slice, so golden diffing (with normalization) is the primary safety net.
- **Guardrail:** ensure the five guest subcommands (`age-key`, `ephemeral-ssh`, `home-manager-upgrade`, `nixos-switch`, `home-switch`) still dispatch after the `vm.Run` refactor — add a `TestVMGuestDispatch` covering each.

## Effort / risk

| Slice | Effort | Risk | Notes |
|---|---|---|---|
| VM host + control | Moderate | Medium | State schema + QEMU launch; high payoff (true `vm` unification) |
| MCP | Moderate | **High** | Must keep JSON-RPC contract; add smoke test |
| shell | Low–Moderate | Low | Mostly env + exec; closes the missing-wrapper gap |
| analyze | **High** (largest) | **High** | 34 sections, custom Nix lexer, Mermaid graph, git churn; do **last** with golden diff |

**Guardrails:** systemd units (`runtime/vm/*.nix`) call `angst vm age-key`/`ephemeral-ssh`/`nixos-switch`/`home-switch`/`home-manager-upgrade` — keep those names intact. No new Go deps.

## Suggested phasing (detailed)

**Phase 1 — VM host + MCP + flake rewiring**
- Add `internal/vm/host.go`, `control.go`, `health.go`, `mcp.go`; extend `vm.Run` with host/`mcp` branch.
- Add `vmTool` wrapper in `runtime/default.nix` (full PATH). Re-point `apps.nix`/`packages.nix`/`context.nix`/`devshell.nix`/`mkHome.nix`/`justfile` `vm`/`vm-ssh`.
- *Verify:* `nix run .#vm -- status` (no VM → graceful), `nix run .#vm -- mcp status`, MCP smoke test green, `go test ./internal/vm/...`.
- *Verify:* `nix build .` still succeeds; systemd units resolve.

**Phase 2 — shell + wrapper**
- Add `internal/shell/shell.go`; add `angstShell` `mkScript` (bakes `SHELL_*` env). Re-point `shell` app/package/home package.
- *Verify:* `nix run .#shell -- dev` enters dev shell with tree-sitter symlinks + correct `PATH`; `safe` analogous.

**Phase 3 — analyze (last)**
- Add `internal/analyze/*`. Re-point `runtime/apps/analyze*.nix` + `justfile analyze`.
- *Verify:* `nix run .#analyze -- --output /tmp/analysis.md`; **regenerate** `analysis.md` from the Go port and confirm it differs from the Python one only where expected (language/LOC breakdown); snapshot test passes with normalized volatile numbers. `go test ./internal/analyze/...` snapshot passes.

**Phase 4 — delete & finalize**
- Delete `tools/{vm,shell,analyze_flake}`. Remove now-dead `tools/vm`/`tools/shell` excludes from the analyze port's `rg` excludes.
- Run `go test ./...`, `nix build .`, `just analyze` to regenerate `analysis.md`.
- Update `README.md` prose to match the Go tooling (the `rg` check below will surface those references; they are not auto-fixed).
- Confirm no remaining references to `tools/` via `rg tools/vm tools/shell tools.analyze_flake` (this will surface `README.md` prose references — update those manually).

## Rollback

- Each phase is independently revertible via git. **Phase 1 must land as a single atomic commit** — remove `vmOutputs`/`shellOutputs` from `context.nix` *together with* the new `runtime.vmTool`/`runtime.angstShell` outputs and the Go host/`mcp` code, so `nix build .` stays green. The Rust/Python sources stay on disk (unreferenced via the flake) until Phase 4, so they remain a fallback by direct path if a Phase 1–3 regression is found.
- Keep `vm`/`shell`/`analyze` apps pointing at `runtime` outputs only after their Go equivalents are verified; otherwise temporarily keep Rust apps until Phase sign-off.

## Open questions

1. Should `vmTool` extend the existing `goAngst` wrapper (simpler, larger closure on every `angst` invocation) or be a separate `makeWrapper` (cleaner PATH scoping)? *Recommend separate `vmTool`.*
2. For `analyze` golden diff: the golden file must be **regenerated from the Go port** — the Python output is not a valid baseline once `tools/` is gone (the language/LOC section changes). *Recommend asserting exact match on headings + section count (34), with a normalization step tolerating whitespace/ordering and volatile churn/eval numbers. Do NOT assert byte-for-byte equality of the whole report.*
3. Is `defaultVmHost` (`"vm"`) to be hardcoded in `devshell.nix` or read from a flake param? *Recommend hardcoded `"vm"`.*

## Current `tools/` reference map (for the port)

### `tools/vm` (Rust workspace)
- Crates: root `vm` binary (`src/main.rs` → `vm_cli::run_cli`), `vm-core` (config/shared-dir/ssh-engine/runner/process-controller), `vm-cli` (CLI + host subcommands + `mcp` dispatch), `vm-mcp` (axum JSON-RPC server + service manager).
- Host commands: `start` (validate `vm` profile, kill stale QEMU, `nix build .#nixosConfigurations.<host>.config.system.build.vm`, launch `result/bin/run-<host>-vm`, poll SSH up to ~1500s), `stop`/`restart`, `status`, `health` (qemu pgrep + hostfwd + port 2222 + ssh), `logs`, `ssh` (shells out to system `ssh` on `127.0.0.1:2222`), `exec`, `copy-to`/`copy-from` (SCP).
- `vm-mcp`: axum on `127.0.0.1:8765`, `POST /mcp` (JSON-RPC requests) **+ `GET /mcp` (`text/event-stream` Streamable-HTTP stream)**, `GET /health`; tools `vm_exec`/`vm_status`/`vm_restart`; managed by `VmProcessController` (`start`/`stop`/`restart`/`status`/`logs`).
- Env: `VM_SSH_PORT`(2222), `VM_SSH_USER`/`ANGST_USERNAME`(joao), `VM_SSH_IDENTITY`(`~/.ssh/id_ed25519`), `NIX_DEFAULT_TARGET_HOST`/`ANGST_HOST`, `ANGST_REPO`, `NIX_DISK_IMAGE`, `XDG_STATE_HOME`, `VM_STATE_DIR`, `DISPLAY`/`WAYLAND_DISPLAY` (headless auto), `ANGST_PASSWORD`. Sets for runner: `SHARED_DIR`, `ANGST_REPO`, `NIX_DISK_IMAGE`, `QEMU_NET_OPTS=hostfwd=tcp::2222-:22`, `QEMU_OPTS=-display none` when headless.
- State: `<VM_STATE_DIR>/<service>.json` + `logs/<service>.log`.

### `tools/shell` (Rust)
- Subcommands `dev`/`safe`. Reads `SHELL_DEV_PATH`/`SHELL_SAFE_PATH` (required), optional `SHELL_DEV_ENTRY` (dev only), `SHELL_ENABLED_SHELLS` (else `$SHELL`/`/bin/bash`), `SHELL_TS_PARSERS`/`SHELL_TS_QUERIES` (symlinked into `~/.local/share/tree-sitter`). Sets `PATH`, `IN_NIX_SHELL`, `name`, `SHELL_MODE`, `ORIGINAL_SHELL`, then `exec`s host shell (or `SHELL_DEV_ENTRY`).
- Note: the Nix wrapper that injects those env vars was never built; the Go port must supply it.

### `tools/analyze_flake` (Python)
- `tools/analyze_flake/__main__.py` + `util.py` + `sections/{overview,graph,inventory,analysis,quality,churn,coverage}.py` → 34 numbered Markdown sections to stdout or `-o FILE` (`analysis.md`). Flags: `--no-eval-cost`, `--no-graph`, `-o/--output`.
- Inputs: text-based via `rg` (`RG_EXCLUDES=[!.git,!result,!tools/vm/**,!tools/shell/**]`) and `Path.rglob("*.nix")`; shells out to `nix`, `git`, optional `deadnix`/`statix`. Must run from repo root.
- Invoked by `just analyze` and `runtime/apps/{analyze,analyze-to-file}.nix` via `python3 -m tools.analyze_flake`.
