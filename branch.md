# branch: infra/logger minimal

Scope: log system only, split ownership. Minimal leaves only: `infra/lib/types.nix`, `infra/contracts/codes.nix`, `infra/contracts/levels.nix`, `infra/contracts/secret-ref.nix`. No `compose/context`. No `catalog/hosts/<host>/target.nix`. No `angst host detect`. No `workflow/activate`. No `workflow/validate` gates/behavior. No `systems/secrets` provisioning. No `infra/monads` full. No `infra/state` full. No `infra/cli` split. No production callers.

Source spec: `architecture.md` `## Logging`, `## Infra`, `## Workflow Phase Contracts`.

Target: `infra/lib/types.nix` + `infra/contracts/codes.nix` + `infra/contracts/levels.nix` + `infra/contracts/secret-ref.nix` + `workflow/phases.nix` + `infra/logger/default.nix` thin facade + `infra/logger` Go + tests. JSONL canonical. Human view only view. `SecretRef` only, never values. Logger defines shapes/render/throw only; vocab lives in `infra/contracts`.

---

## Step 0 — baseline, no code

- [x] Run `NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure` from clean tree, save output
- [x] Confirm root holds `flake.nix`, `architecture.md`, `.editorconfig`, `.git/`
- [x] Confirm `flake.nix` owns no logic yet

Done when: baseline output saved. No files changed.

---

## Step 1 — scaffold `infra/logger/` empty

- [x] Create `infra/logger/default.nix` empty facade with TODO, no exports yet
- [x] Create `infra/logger/go.mod` single module
- [x] Create `infra/logger/logger.go` empty package `logger`, no funcs yet
- [x] Create `infra/logger/logger_test.go` empty test, fails closed until schema lands
- [x] Wire `infra/logger/default.nix` into `flake.nix` outputs only for `nix flake check`, no consumers
- [x] Run `NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure`

Done when: dirs exist. Check stays green. Zero callers.

---

## Step 2 — Nix event schema, split ownership

Files: `infra/lib/types.nix`, `infra/contracts/codes.nix`, `infra/contracts/levels.nix`, `infra/contracts/secret-ref.nix`, `infra/logger/default.nix`

Ownership: generic asserts -> `infra/lib/types.nix` (no domain logic). `codes`/`levels`/`SecretRef` vocab -> `infra/contracts` (public, importable by `compose`/`systems`/`workflow`/`infra`). Gate behavior stays `workflow/validate`, provisioning/redaction stays `systems/secrets` (future, not this branch). Shapes + `render` + `throwDiagnostics` -> `infra/logger` facade only. `infra/lib/types.nix` imports only nixpkgs lib. Contracts import only `infra/lib/types.nix`. Facade `let`-imports contracts + `infra/lib/types.nix`, drops `rec`, re-exports same public names. JSON keys byte-identical to `## Logging` example.

- [ ] Create `infra/lib/types.nix`: minimal, not full pre-refac `lib/core/` port. `isNonEmptyStr`, `isRelPath`, `isBasename`, `require`, `checks` list + `firstError` fold (same idiom as pre-refac `lib/domains/mkDomain.nix`). Rejects `""`, `[ ]`, `{ }`. No `TGT`, no `levels`, no `SecretRef`.
- [ ] Create `infra/contracts/codes.nix`: `codes` `TGT`, `PKG`, `PROF`, `DESK`, `CTX`, `SEC`, `VM`, `PROJ`, `DEP`, `ACT`, `LOG`, `ARCH` + `codePrefix` + `assertCode` (`PREFIXNNN`), imports only `infra/lib/types.nix`
- [ ] Create `infra/contracts/levels.nix`: `levels` `error`, `warn`, `info`, `step` + `assertLevel` + `isLevel`, imports only `infra/lib/types.nix`. Canonical wire lowercase.
- [ ] Create `infra/contracts/secret-ref.nix`: `SecretRef` `{ ref }` only + `isSecretRef` + `isSecretKey` + `assertSecretRefsOnly` + `assertNoKnownSecrets`, imports only `infra/lib/types.nix`. Not just null/string: recursive secret-field walk, known-value guard. Shape here, behavior stays `systems/secrets` later.
- [ ] Rewrite `infra/logger/default.nix` thin facade: `let`-import 3 contracts + `infra/lib/types.nix`, keep `diagnostic` `{ code, scope, host, packages, phase, message, data }`, `event` `{ ts, level, code, scope, host, packages, phase, message, data }`, `render*`, `throwDiagnostics` (grouped collect-all, single throw, no warn mode), `toJSONL`; drop `rec`
- [ ] Keep JSON shape from `## Logging`: `ts`, `level`, `code`, `scope`, `host`, `packages`, `phase`, `message`, `data`
- [ ] Keep edge reject: plain secret strings -> throw, known secret values -> throw, bad code/level -> throw, `throwDiagnostics []` -> null else grouped throw
- [ ] Forbid `VERBOSE_ECHO`, raw `echo "==>"`, ad-hoc `fmt.Printf` in new code
- [ ] Run `NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure`

Done when: 5 files evaluate. No printing. No IO. No cycles. Contracts import only types.

---

## Step 3 — phase/state literals, single source

Files: `workflow/phases.nix`, `infra/logger/default.nix`, `infra/lib/types.nix`, `infra/contracts/codes.nix`, `infra/contracts/levels.nix`, `infra/contracts/secret-ref.nix`

- [ ] Create `workflow/phases.nix` with `phases = [ "evaluate" "validate" "build" "activate" "verify" "finish" ]`
- [ ] Add `states = [ "pending" "running" "ok" "warn" "error" "skipped" ]` in same file
- [ ] Import phase/state shapes from `workflow/phases.nix` into `infra/logger/default.nix`, no redefinition
- [ ] Reserve `workflow/validate/report.nix` as only other allowed phase/state literal site, do not create it now
- [ ] Add test split: phase/state literals outside `workflow/`, `infra/logger` (re-export only), `workflow/validate/report.nix` would fail `ARCH`; `codes`/`levels`/`SecretRef` vocab outside `infra/contracts/` (plus re-export in `infra/logger`) would fail `ARCH`
- [ ] Run `NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure`

Done when: one source. No dup literals.

---

## Step 4 — Go logger, fresh from spec

Target: `infra/logger/`

- [ ] Define `Level`: `ERROR`, `WARN`, `STEP`, `INFO`, mirrored from `infra/contracts/levels.nix`
- [ ] Define `LevelOf`: map backend lines to `ERROR`, `WARN`, `STEP`, else `INFO`
- [ ] Define color helpers: `ColorBadge`, `Reset`, `GreenBold`, `Green`, `DarkGray` with `ansiReset`, `ansiRedBold`, `ansiYellowBold`, `ansiCyanBold`, `ansiDarkGray`, `ansiGreenBold`, `ansiGreen`
- [ ] Define `StateDir`: honor `ANGST_STATE_DIR`, else `~/.local/state/angst/`
- [ ] Add JSONL writer: `ts`, `level`, `code`, `scope`, `host`, `packages`, `phase`, `message`, `data`
- [ ] Add sinks: stderr + `~/.local/state/angst/logs/`
- [ ] Honor `ANGST_STATE_DIR`, `ANGST_LOG_LEVEL`, `ANGST_LOG_FORMAT`, `ANGST_LOG_DIR`
- [ ] Keep user-owned `~/.local/state/angst/`, override via `ANGST_STATE_DIR`
- [ ] Wrap backend lines as `source=nixos-rebuild` or `source=home-manager` events, keep `LevelOf` fallback
- [ ] Include phase/state transitions in activation events
- [ ] Add snapshot test: Nix `levels` (`infra/contracts/levels.nix`) <-> Go `Level` parity (wire lowercase `error`, `warn`, `info`, `step`), Nix `codes` (`infra/contracts/codes.nix`) stable
- [ ] Run `gofmt -l .`
- [ ] Run `CGO_ENABLED=0 go vet ./...`
- [ ] Run `CGO_ENABLED=0 go test ./...`

Done when: new tests pass. New writer compiles. No callers switched yet.

---

## Step 5 — redaction + perms, fail closed

Files: `infra/logger/*`, `infra/logger/default.nix`, `infra/lib/types.nix`, `infra/contracts/secret-ref.nix`, `infra/contracts/levels.nix`, `infra/contracts/codes.nix`

- [ ] Scrub backend/script output to `SecretRef` before `events.jsonl` and `raw.log`
- [ ] Keep scrubbed `raw.log` authoritative, mode `0600`
- [ ] Enforce `0700` dirs, `0600` sensitive files
- [ ] Never log secret values, only `SecretRef`
- [ ] Sanitize env on sudo paths; no secret env leak; sudo only for `nixos-rebuild switch` later, not now
- [ ] Add redaction test: secret string in -> `SecretRef` out, raw value absent in `events.jsonl` and `raw.log`
- [ ] Add perms test: dirs `0700`, sensitive `0600`
- [ ] Add snapshot test: log event JSON keys stable, codes stable: `TGT`, `PKG`, `PROF`, `DESK`, `CTX`, `SEC`, `VM`, `PROJ`, `DEP`, `ACT`, `LOG`, `ARCH`; Nix `codes`/`levels` match Go `Level`/codes mirror
- [ ] Add import-path test: `infra/lib/types.nix` imports only nixpkgs lib; contracts import only `infra/lib/types.nix`; no leaf imports `infra/logger`; no `infra/logger` -> `workflow/*` / `systems/*` edges
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

- [ ] Confirm zero imports of `infra/logger` outside `infra/logger` tests; facade imports (`infra/lib/types.nix`, `infra/contracts/codes.nix`, `infra/contracts/levels.nix`, `infra/contracts/secret-ref.nix`, `workflow/phases.nix`) are the only allowed new edges
- [ ] Confirm no `compose/`, `systems/` behavior, `workflow/` gates depend on new log; minimal leaves hold vocab only
- [ ] Confirm `catalog/*` untouched (may import `infra/lib/` only, never `infra/contracts/`)
- [ ] Run `NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure`
- [ ] Run `CGO_ENABLED=0 go test ./...` in `infra/logger`
- [ ] Save schema hash for next branch (`compose/context`, `catalog/hosts/<host>/target.nix`): hash all 6 Nix files (`infra/lib/types.nix`, `infra/contracts/codes.nix`, `infra/contracts/levels.nix`, `infra/contracts/secret-ref.nix`, `workflow/phases.nix`, `infra/logger/default.nix`)

Done when: both gates green. Branch mergeable. Next branch may add `compose/context` + `angst host detect`.
