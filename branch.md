# branch: infra/log minimal

Scope: log system only. No `compose/context`. No `catalog/hosts/<host>/target.nix`. No `angst host detect`. No `workflow/activate`. No `workflow/validate`. No `infra/monads` full. No `infra/state` full. No `infra/cli` split. No production callers.

Source spec: `architecture.md` `## Logging`, `## Infra`, `## Workflow Phase Contracts`.

Target: `infra/log/default.nix` + `infra/log/go/logger` + tests. JSONL canonical. Human view only view. `SecretRef` only, never values.

---

## Step 0 — baseline, no code

- [ ] Run `NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure` from clean tree, save output
- [ ] Confirm root holds `flake.nix`, `architecture.md`, `.editorconfig`, `.git/`
- [ ] Confirm `flake.nix` owns no logic yet

Done when: baseline output saved. No files changed.

---

## Step 1 — scaffold `infra/log/` empty

- [ ] Create `infra/log/default.nix` empty facade with TODO, no exports yet
- [ ] Create `infra/log/go/logger/go.mod` single module
- [ ] Create `infra/log/go/logger/logger.go` empty package `logger`, no funcs yet
- [ ] Create `infra/log/go/logger/logger_test.go` empty test, fails closed until schema lands
- [ ] Wire `infra/log/default.nix` into `flake.nix` outputs only for `nix flake check`, no consumers
- [ ] Run `NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure`

Done when: dirs exist. Check stays green. Zero callers.

---

## Step 2 — Nix event schema, pure data only

File: `infra/log/default.nix`

- [ ] Define `codes`: `TGT`, `PKG`, `PROF`, `DESK`, `CTX`, `SEC`, `VM`, `PROJ`, `DEP`, `ACT`, `LOG`, `ARCH`
- [ ] Define `levels`: `error`, `warn`, `info`, `step`
- [ ] Define `diagnostic`: `{ code, scope, host, packages, phase, message, data }`
- [ ] Define `event`: `{ ts, level, code, scope, host, packages, phase, message, data }`
- [ ] Match JSON example shape from `## Logging`: `ts`, `level`, `code`, `scope`, `host`, `packages`, `phase`, `message`, `data`
- [ ] Define `SecretRef`: `{ ref }` only. Reject plain secret strings at schema edge
- [ ] Add `throwDiagnostics`: grouped collect-all, single throw, no warn mode
- [ ] Add `render`: human terminal view, JSONL stays canonical
- [ ] Forbid `VERBOSE_ECHO`, raw `echo "==>"`, ad-hoc `fmt.Printf` in new code
- [ ] Run `NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure`

Done when: schema evaluates. No printing. No IO.

---

## Step 3 — phase/state literals, single source

Files: `workflow/phases.nix`, `infra/log/default.nix`

- [ ] Create `workflow/phases.nix` with `phases = [ "evaluate" "validate" "build" "activate" "verify" "finish" ]`
- [ ] Add `states = [ "pending" "running" "ok" "warn" "error" "skipped" ]` in same file
- [ ] Import phase/state shapes from `workflow/phases.nix` into `infra/log/default.nix`, no redefinition
- [ ] Reserve `workflow/validate/report.nix` as only other allowed literal site, do not create it now
- [ ] Add test: literals outside `workflow/`, `infra/log`, `workflow/validate/report.nix` would fail `ARCH`
- [ ] Run `NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure`

Done when: one source. No dup literals.

---

## Step 4 — Go logger, fresh from spec

Target: `infra/log/go/logger/`

- [ ] Define `Level`: `ERROR`, `WARN`, `STEP`, `INFO`
- [ ] Define `LevelOf`: map backend lines to `ERROR`, `WARN`, `STEP`, else `INFO`
- [ ] Define color helpers: `ColorBadge`, `Reset`, `GreenBold`, `Green`, `DarkGray` with `ansiReset`, `ansiRedBold`, `ansiYellowBold`, `ansiCyanBold`, `ansiDarkGray`, `ansiGreenBold`, `ansiGreen`
- [ ] Define `StateDir`: honor `ANGST_STATE_DIR`, else `~/.local/state/angst/`
- [ ] Add JSONL writer: `ts`, `level`, `code`, `scope`, `host`, `packages`, `phase`, `message`, `data`
- [ ] Add sinks: stderr + `~/.local/state/angst/logs/`
- [ ] Honor `ANGST_STATE_DIR`, `ANGST_LOG_LEVEL`, `ANGST_LOG_FORMAT`, `ANGST_LOG_DIR`
- [ ] Keep user-owned `~/.local/state/angst/`, override via `ANGST_STATE_DIR`
- [ ] Wrap backend lines as `source=nixos-rebuild` or `source=home-manager` events, keep `LevelOf` fallback
- [ ] Include phase/state transitions in activation events
- [ ] Run `gofmt -l .`
- [ ] Run `CGO_ENABLED=0 go vet ./...`
- [ ] Run `CGO_ENABLED=0 go test ./...`

Done when: new tests pass. New writer compiles. No callers switched yet.

---

## Step 5 — redaction + perms, fail closed

Files: `infra/log/go/logger/*`, `infra/log/default.nix`

- [ ] Scrub backend/script output to `SecretRef` before `events.jsonl` and `raw.log`
- [ ] Keep scrubbed `raw.log` authoritative, mode `0600`
- [ ] Enforce `0700` dirs, `0600` sensitive files
- [ ] Never log secret values, only `SecretRef`
- [ ] Sanitize env on sudo paths; no secret env leak; sudo only for `nixos-rebuild switch` later, not now
- [ ] Add redaction test: secret string in -> `SecretRef` out, raw value absent in `events.jsonl` and `raw.log`
- [ ] Add perms test: dirs `0700`, sensitive `0600`
- [ ] Add snapshot test: log event JSON keys stable, codes stable: `TGT`, `PKG`, `PROF`, `DESK`, `CTX`, `SEC`, `VM`, `PROJ`, `DEP`, `ACT`, `LOG`, `ARCH`
- [ ] Run `CGO_ENABLED=0 go test ./...`
- [ ] Run `NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure`

Done when: redaction tests green. Perms enforced. No values leak.

---

## Step 6 — activation artifact shape, no runner

Paths: `~/.local/state/angst/activation/<host>/<run-id>/`, `~/.local/state/angst/activation/<host>/latest`

- [ ] Define filenames only: `summary.json`, `events.jsonl`, `raw.log`
- [ ] Define `summary.json` fields: run ID, host, target, backend, scope, flake ref, start/finish timestamps, total duration, per-phase durations, exit code, status, generation, store path, warning/error counts, log dir
- [ ] Define append-only `events.jsonl` + `raw.log`
- [ ] Define `latest` symlink -> `<run-id>`
- [ ] Define retention: keep last 20 runs, gzip old raw logs, configurable
- [ ] Define per-host activation lock path under `~/.local/state/angst/locks/`, no impl yet
- [ ] Note `~/.local/state/angst/activation/` for runs, `~/.local/state/angst/vm/` for VM, `~/.local/share/angst/` for durable data, `~/.cache/angst/` for caches, `$XDG_RUNTIME_DIR/angst/` for ephemera. Logs use state path now, others later
- [ ] No `workflow/activate` code in this branch

Done when: shape documented in code as types/consts. No runner writes yet.

---

## Step 7 — gates, still no callers

- [ ] Confirm zero imports of `infra/log` outside `infra/log/go/logger` tests
- [ ] Confirm no `compose/`, `systems/`, `workflow/` behavior depends on new log
- [ ] Confirm `catalog/*` untouched
- [ ] Run `NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure`
- [ ] Run `CGO_ENABLED=0 go test ./...` in `infra/log/go/logger`
- [ ] Save `infra/log` schema hash for next branch (`compose/context`, `catalog/hosts/<host>/target.nix`)

Done when: both gates green. Branch mergeable. Next branch may add `compose/context` + `angst host detect`.
