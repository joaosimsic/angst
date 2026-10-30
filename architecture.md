# angst architecture

---

Previous version can be seen on ~/projects/angst-pre-refac/

---

Proposed architecture. Current code is still on the old layout; this document
defines the target and the migration path.

## Goals

- Buckets are top-level, not hidden under one `systems/` label. Capabilities,
  pipelines, infra, and governance differ widely, so each gets its own root:
  `capabilities/`, `pipelines/`, `infra/`, `governance/`, plus `catalog/`.
- `catalog/` holds data only: feature records and builds, toolchain specs,
  runtime tool records and builds, profiles, hosts. It holds no behavior.
- Time and ownership stay separate. Phases (`resolve -> validate -> build ->
  activate -> verify -> finish`) describe *when* work happens. Buckets describe
  *who* owns it. Exactly one pipeline owns sequencing: `pipelines/activation`.
- Eval, build, activation, and run are distinct planes with explicit logging
  and step validation. No plane hides inside another.
- `infra/monads/` is the edge: ports, interpreters, effect composition, and
  one central test suite.
- Each `catalog/features/<category>/<name>/` directory is a real Nix package:
  `src/` lives inside it, inputs (`theme`, `toolchains`) are explicit
  function arguments, and theme/toolchain values are baked into the store
  output.
- Feature implementations are co-located with their package builds.
- `catalog/features/` is the new name for what is currently `domains/`.
- Package versions are git-derived (flake `self.shortRev` /
  `self.dirtyShortRev`, fallback `"dev"`); no hardcoded versions.
- No separate `derivations/` directory. Shared build helpers are consumed via
  `callPackage` dependencies, not via a shared recipe directory.
- `infra/lib/` contains only shared pure utilities. `infra/nixpkgs-config.nix`
  is the single nixpkgs configuration; there are no root-level exceptions.
- Profiles are graph nodes with requirements and constraints.
- Every bucket exposes a narrow facade; internal modules are private.
- Target identity and runtime state are observed, not declared in the host.
- Host context distinguishes desired, observed, and derived data.
- Runtime probing and deployment stay outside flake evaluation.
- All runtime output uses one structured logging system.
- `angst switch` is the only system-activation entry point. It selects the
  backend from tracked target state, never from a hidden default, and records
  structured phase/log artifacts.
- Runtime executables are separate opt-in artifacts, not one all-features
  binary.
- No root `systems/`, `lib/`, `domains/`, `modules/`, `checks/`, `runtime/`,
  `toolchains/`, `themes/`, `packages/`, `profiles/`, `hosts/`, or `flake/`
  directories.

## Buckets

Four buckets plus a data catalog. Nothing lives under a shared `systems/`
label.

| Bucket | Owns | Directories |
|---|---|---|
| Capabilities | Facts, builds, domain state | `capabilities/packages/`, `capabilities/platform/`, `capabilities/theme/`, `capabilities/host/`, `capabilities/context/`, `capabilities/persistence/`, `capabilities/secrets/`, `capabilities/vm/`, `capabilities/projects/` |
| Pipelines | Time, sequencing, backend selection | `pipelines/activation/`, `pipelines/modules/` |
| Infra | Seams, IO, rendering, exposure, shared helpers | `infra/monads/`, `infra/state/`, `infra/log/`, `infra/cli/`, `infra/outputs/`, `infra/lib/`, `infra/nixpkgs-config.nix` |
| Governance | Rules, no execution | `governance/validation/` (`matrix.nix`, `report.nix`, `internal/architecture.nix`) |
| Catalog | Data only, zero behavior | `catalog/features/`, `catalog/toolchains/`, `catalog/runtime/`, `catalog/profiles/`, `catalog/hosts/` |
| Secrets source | Encrypted data only | `secrets/` |

NixOS and home-manager modules are adapters at the edge. They receive plain
facts and modules. They never see monads.

## Root Layout

```text
flake.nix
architecture.md
catalog/
  features/
    <category>/<name>/
      default.nix
      package.nix
      src/
      home.nix
      system.nix
      checks.nix
      config/
  toolchains/
    _builder.nix
    _schema.nix
    <language>.nix
  runtime/
    <tool>/
      default.nix
      package.nix
      src/
  profiles/
    <profile>.nix
  hosts/
    <host>/
      default.nix
      target.nix
      hardware.nix
      observations.nix
capabilities/
  packages/
  platform/
  theme/
    themes/
  host/
  context/
  persistence/
  secrets/
  vm/
  projects/
pipelines/
  activation/
  modules/
infra/
  monads/
    ports/
    interpreters/
    tests/
  state/
  log/
    go/logger/
  cli/
    go.mod
    cmd/angst/
    cmd/angst-switch/
    cmd/angst-projects/
    cmd/angst-secrets/
    cmd/angst-vm/
    cmd/angst-shell/
    cmd/angst-analyze/
    cmd/angst-hm-switch/
    cmd/angst-log/
    internal/platform/
    internal/commands/
    wrappers/
  outputs/
  lib/
  nixpkgs-config.nix
governance/
  validation/
    matrix.nix
    report.nix
    internal/architecture.nix
secrets/                       # encrypted data only
githooks/
.github/
```

Removed or banned root directories:

- `systems/` (the old shared label; buckets are top-level now)
- `lib/` (moved to `infra/lib/`)
- `domains/`
- `modules/`
- `checks/`
- `runtime/`
- `toolchains/`
- `themes/`
- `packages/` (renamed to `catalog/features/`, `catalog/toolchains/`,
  `catalog/runtime/`)
- `profiles/` (moved to `catalog/profiles/`)
- `hosts/` (moved to `catalog/hosts/`)
- `flake/`

`infra/nixpkgs-config.nix` is the single nixpkgs configuration. There are no
root-level exceptions: the root holds only `flake.nix`, `architecture.md`,
`catalog/`, `capabilities/`, `pipelines/`, `infra/`, `governance/`, and
`secrets/`.

## Planes: Eval, Build, Activate, Run

Four planes. Each has explicit inputs, gates, logs, and artifacts. No plane
hides inside another.

- Eval is pure Nix over tracked files only. It reads `catalog/**/default.nix`,
  `catalog/hosts/<host>/target.nix`, `catalog/hosts/<host>/hardware.nix`, and
  `secrets/**/*.age` presence only. It emits modules, derivations, and
  diagnostics. It never probes live processes, SSH, QEMU, decrypted values,
  or runtime logs.
- Build runs `package.nix` derivations into `/nix/store`. Inputs are explicit:
  `theme`, `toolchains`, `src`, `upstream`, `version` from `self.shortRev` /
  `self.dirtyShortRev` with fallback `"dev"`. Theme and toolchain values are
  baked into `$out` here, never rendered as eval text.
- Activate switches generations: `nixosConfigurations.<host>` into
  `/run/current-system` via `nixos-rebuild switch` (needs sudo), or
  `homeConfigurations.<host>` into `~/.nix-profile` via `home-manager switch`
  (needs no sudo). Backend selection comes only from the tracked
  `target.nix`. There is no probing, no target write, and no fallback during
  activation.
- Run executes live processes only: Go binaries, SSH, QEMU probes, mounts,
  health checks. State lands under `~/.local/state/angst/`, durable data
  under `~/.local/share/angst/`, caches under `~/.cache/angst/`, ephemera
  under `$XDG_RUNTIME_DIR/angst/`. Run never happens during eval.

Old blur this replaces: `runtime/angst/internal/render/render.go` mixed
`nix eval` with file writes and `i3-msg reload` in one path;
`runtime/*.nix` shims mixed home modules with exec wrappers;
`lib/render.nix` plus `domains/.../render.nix` emitted config text silently;
`justfile` mixed `nix build` with `sudo nixos-rebuild switch` with raw output
only. Each of those is now assigned to exactly one plane with its own logs.

## Pipeline Ownership × Time Matrix

Phases:

```text
resolve -> validate -> build -> activate -> verify -> finish
```

States:

```text
pending | running | ok | warn | error | skipped
```

The matrix below is enforced by `governance/validation/matrix.nix`, not a
design guide. Cells: O owns, R reads, W writes, X forbidden, - absent.

| Component | resolve | validate | build | activate | verify | finish |
|---|---|---|---|---|---|---|
| `capabilities/packages` | O | R | W | - | - | - |
| `capabilities/host-context` | O | R | R | - | R | - |
| `capabilities/platform-theme` | R | R | W | - | - | - |
| `capabilities/secrets-vm-projects-persistence` | - | R | - | W | R | - |
| `catalog/*` | W | R | R | - | - | - |
| `secrets/` | - | R | - | - | - | - |
| `pipelines/activation` | R | R | R | O | O | O |
| `pipelines/modules` | - | - | O | - | - | - |
| `infra/monads` | W | W | - | - | - | - |
| `infra/state` | - | R | - | W | W | W |
| `infra/lib` | R | R | R | - | - | - |
| `infra/log` | W | W | W | W | W | W |
| `infra/cli-outputs` | - | - | R | W | R | R |
| `governance/validation` | - | O | - | - | R | R |

Reading:

- `resolve`: `capabilities/packages` plus `capabilities/host` and
  `capabilities/context` emit the `SystemPlan` plus context through the
  `infra/monads` seam. `pipelines/activation` tracks phase state only.
  `infra/log` emits start/end plus selection counts. `governance/validation`
  is absent.
- `validate`: `governance/validation` owns gates `ARCH`, `PROF001`,
  `DESK001`, `DESK002`, `DESK003`, `TGT001`, `SEC`, `CTX`. Capabilities are
  read-only. `infra/state` checks schemas and permissions. Required facts
  fail closed on `unknown`, `failed`, or stale.
- `build`: `pipelines/modules` pairs selected records, invokes `package.nix`
  with `theme`, `toolchains`, `upstream`, `src`, and git-derived `version`,
  and emits home-manager and NixOS modules that install `$out` from
  `/nix/store`.
- `activate`: `pipelines/activation` selects the backend from `target.nix`:
  `nixos` local uses `nixos-rebuild switch`; `generic-linux` local uses
  `home-manager switch`; `nixos` remote uses `nixos-rebuild --target-host`;
  `generic-linux` remote builds, copies, and activates over SSH.
- `verify`: activation re-probes the target and compares it with
  `target.nix`. Mismatch stops the run; only `angst host detect`
  regenerates the manifest. `governance/validation` runs health checks and
  records generation plus store path.
- `finish`: artifacts land under
  `~/.local/state/angst/activation/<host>/<run-id>/` as `summary.json`,
  `events.jsonl`, and `raw.log`, with a `latest` symlink, 20-run retention,
  gzipped old raw logs, `0700` directories, and `0600` sensitive files.

## Catalog Discovery

Nix evaluation is pure. `builtins.readDir` is **eval-time source discovery**,
not runtime probing. It is deterministic for a fixed tracked source tree, works
offline, and never inspects the target machine.

Use eval-time discovery for declarative catalogs:

| Catalog | Declaration |
|---|---|
| Themes | file under `capabilities/theme/themes/` |
| Toolchains | file under `catalog/toolchains/` |
| Features | directory under `catalog/features/<category>/<name>/` |
| Runtime tools | directory under `catalog/runtime/<tool>/` |
| Profiles | file under `catalog/profiles/` |
| Hosts | directory under `catalog/hosts/` with `default.nix` |
| Feature checks | `checks.nix` inside the feature directory |

Use explicit imports for code composition:

| Code | Why explicit |
|---|---|
| `capabilities/*`, `pipelines/*`, `infra/*`, `governance/*` | bucket ownership and facade boundaries |
| NixOS/home-manager adapters | module composition and ordering |
| `infra/cli` command registry | binaries and runtime capabilities |
| `infra/monads` ports/interpreters | contracts and test doubles |
| `infra/outputs` | public flake surface |
| `package.nix` builds | invoked per selected package with explicit args, not global discovery |
| Cross-bucket validation | explicit public-facade imports |

Discovered does not mean enabled. Discovery builds a catalog. Hosts, profiles,
and packages still select explicitly.

### Scanner Contract

Every catalog scanner:

- reads one directory
- filters regular `.nix` files
- skips `_*`, `default.nix`, tests, and fixtures
- derives IDs from paths or filenames
- sorts names for deterministic output
- validates entries at eval time
- rejects duplicate IDs
- rejects orphan implementation directories
- returns `{ entries, index, diagnostics }`
- never enables anything by itself

No manual catalog arrays. Directory presence is the declaration.

### Toolchains Like Themes

```text
catalog/toolchains/
  _builder.nix          # mkToolchain helper, skipped by scanner
  _schema.nix           # toolchain spec validation
  rust.nix
  go.nix

capabilities/packages/internal/
  toolchains.nix        # scan, validate, index, resolve
```

Flow:

```text
catalog/toolchains/*.nix
  -> capabilities/packages scan
  -> validate with _schema.nix
  -> build with _builder.nix
  -> index by language
  -> get("rust")
  -> host selection
```

Rules:

- skip `_*.nix`
- filename is the language ID
- no static language list
- toolchain specs may import local `_builder.nix`
- toolchain specs do not import `capabilities/`, `pipelines/`, `infra/`,
  or `governance/`
- `mkToolchain` stays a pure helper; it is not a package build

### Features Like Themes

```text
catalog/features/<category>/<name>/default.nix
  -> scan
  -> derive ID `category.name`
  -> validate package schema
  -> pair with side files
  -> index
```

Single-level feature:

```text
catalog/features/notifications/default.nix
  -> id `notifications`
```

Rules:

- directory with `default.nix` is a feature
- directory without `default.nix` is an error
- side files are optional
- skip `_*` and `config/` internals
- no central feature list
- no manual `entries` array
- `pipelines/modules` pairs selected entries with side files

### Profiles Like Themes

Remove the static `profileMap`.

```text
catalog/profiles/*.nix
  -> scan
  -> filename is profile ID
  -> validate profile node
  -> index
```

Hosts select:

```nix
profiles = [ "desktop" "development" ];
```

Unknown profile fails `PROF001`. Discovery does not enable anything.

### Checks

- feature checks are discovered from selected feature directories
- governance checks are explicitly registered by `governance/validation`
- cross-bucket checks are explicit imports

Feature checks are data-adjacent and co-located. Governance checks are code
with dependencies and must not appear by accident.

### Untracked Files Caveat

Flake evaluation only sees tracked files.

- adding a theme/toolchain/feature requires `git add`
- untracked files are invisible to catalog discovery
- CI always sees tracked files
- local dev can appear inconsistent until `git add`

A Nix eval check cannot reliably see untracked files inside a flake source.

## Dependency Direction

```text
flake.nix
  -> infra/outputs
       -> capabilities/host
       -> governance/validation
       -> infra/cli
       -> capabilities/theme
       -> infra/log
       -> catalog/
       -> infra/lib/
       -> infra/nixpkgs-config.nix

capabilities/host
  -> capabilities/packages
  -> capabilities/context
  -> pipelines/modules
  -> capabilities/platform
  -> pipelines/activation
  -> capabilities/persistence
  -> capabilities/secrets
  -> capabilities/vm
  -> capabilities/projects
  -> capabilities/theme

infra/cli
  -> pipelines/activation
  -> capabilities/persistence
  -> capabilities/secrets
  -> capabilities/vm
  -> capabilities/projects
  -> infra/state
  -> infra/log

governance/validation
  -> public facades only

capabilities/*, pipelines/*, infra/* (except infra/lib), governance/*
  -> infra/lib (helpers only)

infra/lib
  -> infra/lib + nixpkgs lib only
```

Rules:

| Area | Rule |
|---|---|
| `infra/monads` | The edge. Imported only by files under `capabilities/`, `pipelines/`, `infra/`, `governance/`. Never imported by `catalog/*` or `secrets/`. |
| `*/default.nix` (bucket facades) | Public API only. Returns plain data, modules, packages, diagnostics, or monadic programs. Never leaks internals. |
| `*/internal/` | Private to that bucket member. No other member may import it. |
| `infra/lib/` | Imports only `infra/lib/` and nixpkgs lib. Never imports `capabilities/`, `pipelines/`, `catalog/`, or `governance/`. |
| `infra/nixpkgs-config.nix` | Single nixpkgs configuration. Imported by `infra/outputs`, `pipelines/modules`, and capability builds via args. Never hardcoded from `catalog/*`. |
| `catalog/features/*/default.nix` | Pure package data. No imports from `capabilities/`, `pipelines/`, `infra/`, or `governance/` (except local files); no executable logic. |
| `catalog/features/*/package.nix` | Pure build function. Explicit inputs only (`theme`, `toolchains`, `src`, `upstream`, `version`, nixpkgs inputs); never reads `host` or profiles. |
| `catalog/features/*/{home,system}.nix` | Nix module adapters installing the built store path. Local imports only. |
| `catalog/toolchains/` | Declarative toolchain specs. Local `_builder.nix`/`_schema.nix` imports only. |
| `catalog/runtime/` | Runtime tool records plus `package.nix` builds. |
| `catalog/profiles/` | Pure graph data. No executable logic. |
| `secrets/` | Encrypted data only. No code. |
| `catalog/hosts/` | Pure desired data plus generated tracked observations. No code. |

`catalog/*` may import `infra/lib/*` (pure helpers) only. It never imports
capability behavior, pipeline orchestration, non-lib infra, or governance.

Architecture checks enforce these rules with a static import scan. Dynamic
imports cannot be fully checked; keep facades simple.

## The Edge: `infra/monads`

`infra/monads/` is not a private helper. It is the effect boundary and the
central test seam.

```text
Reader Target
  -> State ResolutionState
    -> Writer [LogEvent]
      -> Result Diagnostic
```

- `Reader`: target, external capabilities, catalog, host context, policy.
- `State`: selected packages, providers, sides, order, diagnostics. Ephemeral.
- `Writer`: structured events, not stdout.
- `Result`: failures and accumulated diagnostics.

`State` is not persistence. Persistent state sits behind ports and
repositories.

### Ports

| Port | Pure/test interpreter | Eval interpreter | Runtime adapter owner |
|---|---|---|---|
| `Target` | fixed `Nixos` / `GenericLinux` / `Unknown` | reads tracked `target.nix` | `capabilities/context` |
| `Observations` | fixture facts | reads tracked `observations.nix` | `capabilities/context` |
| `Secrets` | fake refs | checks ciphertext presence | `capabilities/secrets` |
| `VM` | fake lifecycle | none | `capabilities/vm` |
| `Deploy` | plan only | plan only | `pipelines/activation` |
| `Projects` | fixture stores | tracked metadata only | `capabilities/projects` |
| `Log` | captured events | diagnostics only | `infra/log` |
| `State` repositories | in-memory stores | tracked snapshots | `infra/state` plus owning bucket |

Buckets do not call `os.ReadFile`, SSH, QEMU, or `nixos-rebuild` directly.
They call ports. Adapters in the owning buckets perform the effects.

`infra/monads/interpreters/runtime.nix` is a factory that receives an adapter
record. It does not implement OS effects itself.

### Testing

All monad tests live under `infra/monads/tests/`:

- monad laws
- Reader/State/Writer/Result composition
- target unknown/NixOS/generic-Linux fixtures
- profile resolution
- desktop constraints
- capability cardinality
- target-side rejection
- log event snapshots
- secret redaction
- deploy plans without execution
- project/vault state transitions

Consumer buckets use the same fixture interpreters. Unit tests do no
filesystem, network, VM, or SSH work. `governance/validation` runs end-to-end
repo checks.

## Target Model

Pure Nix cannot detect the target OS. `builtins.currentSystem` is the evaluator
platform, not the target. A remote host is invisible to evaluation.

Use a generated, tracked target manifest:

```nix
# catalog/hosts/<host>/target.nix
{
  target = {
    kind = "nixos";          # nixos | generic-linux
    system = "x86_64-linux";
    virtualization = "none"; # none | qemu | ...
  };

  # Capabilities supplied by the host OS, not by Nix packages.
  externalCapabilities = {
    display-server = {
      session = "x11";
      source = "host-os";
    };
  };
}
```

Rules:

- Generated by `angst host detect`, the installer, or a probe.
- Tracked in git. Flakes do not see untracked files.
- Host `default.nix` stays free of `type`.
- `target.kind = "nixos"` emits `homeConfigurations` and `nixosConfigurations`.
- `target.kind = "generic-linux"` emits only `homeConfigurations`.
- Missing manifest: home config only, diagnostic `TGT001`.
- No probing during flake evaluation.
- `target.nix` holds stable observed identity, not volatile runtime state.

`angst switch` is strict:

- target manifest is required
- missing manifest fails `TGT001`; no probing, no implicit write, no fallback
- `angst host detect` is the only command that writes target state
- `target.kind = "nixos"` selects the NixOS backend
- `target.kind = "generic-linux"` selects the home-manager backend
- no `--scope` is required for normal use
- target mismatch fails `TGT003` before build
- `--target-host` explicitly selects remote execution

`hm-switch` and `nixos-switch` are compatibility wrappers only. They are not
the normal activation path.

Remote deployment is not monad work:

```bash
nixos-rebuild switch --flake .#host --target-host user@host --use-remote-sudo
```

`pipelines/activation` builds the deployment plan. `infra/cli` executes it.

## Switch

Primary command:

```bash
angst switch [--host HOST] [--flake REF] [--target-host USER@HOST]
             [--dry-run] [--build-only] [--no-gc] [--json] [--verbose]
```

No manual `home-manager switch` or `nixos-rebuild switch` for normal use. The
wrapper selects the backend.

### Strict Failures

| Case | Result |
|---|---|
| missing `target.nix` | fail `TGT001`, no probe, no write |
| no host match | fail `TGT002`, no first-host fallback |
| multiple host matches | fail `TGT002` |
| target kind unknown | fail `TGT003` |
| NixOS target but no `nixosConfigurations.<host>` | fail `ACT002` |
| generic target but no `homeConfigurations.<host>` | fail `ACT002` |
| backend command missing | fail `ACT003` |

`--dry-run` prints the selected backend and planned command. There is no
implicit target detection or target write in `angst switch`.

### Backend Selection

| Target | Backend |
|---|---|
| `nixos` local | `nixos-rebuild switch` |
| `generic-linux` local | `home-manager switch` |
| `nixos` remote | `nixos-rebuild --target-host` |
| `generic-linux` remote | build activation, copy, activate over SSH |

`--home` and `--system` are explicit overrides only. They do not silently
fallback.

### Phase and State Model

Phases:

```text
resolve -> validate -> build -> activate -> verify -> finish
```

States:

```text
pending | running | ok | warn | error | skipped
```

Phase ownership: `pipelines/activation` is the sole phase owner. No other
bucket runs the state machine. `infra/log` renders it; `governance/validation`
checks it.

Live view:

```text
angst switch nixos
target  nixos (system)
run     01J...

phase      state    time     detail
resolve    ok       0.2s     host=nixos target=nixos
validate   ok       0.1s     capabilities ok
build      running  12.4s    nix build .#nixosConfigurations.nixos...
  nix: building '/nix/store/...'
  nix: copy 42 paths
activate   pending
verify     pending
finish     pending

warnings 0  errors 0  log ~/.local/state/angst/activation/nixos/01J...
```

The live view shows current phase, state, elapsed time, warning/error counts,
and recent child output. It is not an OS process-tree view. Child output lines
carry phase, source, stream, and level. Raw output is always preserved.

If a backend performs build and activation inside one process, phase
boundaries are inferred from its output. Raw logs remain authoritative.

### Stored Run Artifacts

```text
~/.local/state/angst/activation/<host>/<run-id>/
  summary.json
  events.jsonl
  raw.log
```

```text
~/.local/state/angst/activation/<host>/latest -> <run-id>
```

`summary.json` contains:

- run ID, host, target, backend, scope, flake ref
- start/finish timestamps and total duration
- per-phase durations
- exit code and status
- generation and store path
- warning/error counts
- log directory

Rules:

- atomic summary writes
- append-only events and raw logs
- `0700` directories, `0600` sensitive files
- no secrets or decrypted values
- per-host activation lock
- keep last 20 runs per host by default
- gzip old raw logs
- retention configurable

### Observability Commands

```bash
angst status
angst history
angst log list
angst log show <run-id>
angst log tail
```

- `status`: last run per host, backend, generation, duration, counts
- `history`: run list with exit status and duration
- `log show`: structured events plus raw output
- `log tail`: follow an active run

## State and Stores

State is split by lifetime and purity. There is no global mutable store.

### Eval Plane: Pure, Tracked

Only static snapshots enter flake evaluation:

- desired: `catalog/hosts/**/default.nix`, `catalog/profiles/`,
  `catalog/features/`, `catalog/toolchains/`, `catalog/runtime/`
- stable observed: `catalog/hosts/<host>/target.nix`,
  `catalog/hosts/<host>/hardware.nix`
- optional tracked observations required at build time:
  `catalog/hosts/<host>/observations.nix`
- encrypted secret ciphertext: `secrets/**/*.age`

No eval reads live machine state, VM state, decrypted secrets, or runtime logs.

### Runtime Plane: Mutable, Local

Runtime-only state lives under XDG:

```text
~/.local/state/angst/
  observations/
  activation/
    <host>/<run-id>/
      summary.json
      events.jsonl
      raw.log
  vm/
    services/
    logs/
  projects/
  db/
  locks/
  logs/
```

Override with `ANGST_STATE_DIR`.

- `~/.local/share/angst/` holds durable runtime data such as VM disk images.
- `~/.cache/angst/` holds disposable caches.
- `$XDG_RUNTIME_DIR/angst/` holds ephemeral sockets and decrypted VPN/FTP
  material.

### State Classes

| State | Kind | Owner | Location | In eval |
|---|---|---|---|---|
| Host desired config | desired | Host | `catalog/hosts/<host>/default.nix` | yes |
| Target identity | observed stable | Context | `catalog/hosts/<host>/target.nix` | yes |
| External capabilities | observed stable | Context | `target.nix` | yes |
| Hardware | observed stable | Context | `catalog/hosts/<host>/hardware.nix` | yes |
| Install/disk/boot probes | observed volatile | Context | tracked `observations.nix`, or runtime state | only if imported |
| Profiles/packages | desired | Packages | `catalog/profiles/`, `catalog/` | yes |
| Secrets ciphertext | secret | Secrets | `secrets/**/*.age` | file presence only |
| Secret material | secret | Secrets | `~/.secrets` or `$XDG_RUNTIME_DIR/angst` | no |
| Secret availability | observed runtime | Secrets | runtime state or probe | no |
| VM role | observed stable | Context | `target.virtualization` | yes |
| VM lifecycle | runtime | VM | `state/vm/services/*.json` | no |
| Activation run | runtime | Activation | `state/activation/<host>/<run-id>/` | no |
| Project/db/vault sync metadata | runtime | Projects | `state/projects/`, `state/db/` | no |
| Resolved plan | derived | Resolution | memory only | yes, recomputed |
| Logs | runtime | Observability | `state/logs/` | no |

Rules:

- `host type` is target observation, not host declaration.
- `vm` is `target.virtualization` plus runtime lifecycle.
- Derived state is never persisted.
- No derivation is used as a database.
- Stale observations never authorize destructive operations.

### Repositories

Use DDD repositories behind monad ports. Do not call everything “store.”

| Repository | Backing | Owner |
|---|---|---|
| `TargetRepository` | tracked `catalog/hosts/<host>/target.nix` | `capabilities/context` |
| `HardwareRepository` | tracked `catalog/hosts/<host>/hardware.nix` | `capabilities/context` |
| `ObservationRepository` | tracked snapshots or `state/observations/` | `capabilities/context` |
| `SecretRepository` | `secrets/**/*.age` plus runtime decrypted material | `capabilities/secrets` |
| `VmStateRepository` | `state/vm/services/*.json` | `capabilities/vm` |
| `ActivationRepository` | `state/activation/<host>/<run-id>/` | `pipelines/activation` |
| `ProjectStateRepository` | `state/projects/` plus working store | `capabilities/projects` |
| `DbStateRepository` | `state/db/` plus decrypted DB store | `capabilities/projects` |
| `LogRepository` | `state/logs/` | `infra/log` |

Ports live in `infra/monads/ports/`. Production adapters live in the owning
bucket. Test adapters are in-memory or fixture-backed.

Monad `State` remains ephemeral resolution state. It never persists anything.

### Runtime State File Contract

Tracked observations use Nix schemas; mutable runtime state uses this JSON
envelope.

```json
{
  "schemaVersion": 1,
  "host": "nixos",
  "observedAt": "2026-10-21T12:00:00Z",
  "source": "probe",
  "status": "verified",
  "ttlSeconds": 3600,
  "value": {
    "kind": "nixos"
  },
  "evidence": {
    "path": "/etc/NIXOS"
  },
  "digest": "sha256:..."
}
```

Rules:

- `status`: `unknown`, `verified`, or `failed`.
- Freshness is derived from `observedAt` and `ttlSeconds`.
- Missing state is `unknown`, never `false`.
- Required facts fail closed on `unknown`, `failed`, or stale.
- Advisory facts produce diagnostics.
- Unknown `schemaVersion` fails with a diagnostic; do not silently ignore.
- Writes are atomic: temp file, fsync, rename.
- State directories are `0700`; sensitive files are `0600`.
- Locks protect VM, deploy, activation, project sync, and secret operations.

### State Ownership

| Bucket | State ownership |
|---|---|
| `capabilities/context` | target, hardware, observations |
| `capabilities/secrets` | secret refs, availability, provisioning metadata |
| `capabilities/vm` | VM service state, VM logs, VM locks |
| `pipelines/activation` | system switch runs, deploy runs, activation history, logs |
| `capabilities/projects` | project/db/vault sync metadata and working-store state |
| `infra/log` | append-only logs |
| `infra/state` | state root, atomic IO, locks, schema versions |
| `infra/cli` | no state ownership; composes binaries |

Rules:

- one owner per state file
- no cross-bucket writes
- shared state mechanics live in `infra/state`
- append-only logs
- no secret values in state files or logs

Note the three meanings of “state” and keep them apart: monad `State` is
ephemeral resolution state; `infra/state` is generic runtime IO mechanics;
runtime dirs under `~/.local/state/angst/` are the actual mutable data.

### `target.nix` vs Runtime State

`target.nix` is stable observed identity, not runtime state:

- target kind
- system architecture
- virtualization
- external host-OS capabilities

It is generated, tracked, and reviewed. Activation re-probes the target and
compares. Mismatch stops the operation and instructs the user to regenerate it.

Volatile facts such as disk layout, boot mode, secret availability, and VM
liveness do not belong in `target.nix`.

### Secrets vs State

- Encrypted source of truth stays in `secrets/`.
- Decrypted material stays outside state: `~/.secrets` or
  `$XDG_RUNTIME_DIR/angst`.
- State stores references, hashes, and availability, never secret values.
- Logs and diagnostics emit `SecretRef`, never values.
- `capabilities/secrets` owns provisioning. `pipelines/activation` consumes it.

### `infra/lib` (No Global Store)

There is no global mutable store, and no `store.nix`. Facts flow explicitly:

- `capabilities/context` desired/observed/derived context
- `capabilities/packages` capability providers and derived facts
- feature modules receive `facts` instead of `store`

Derived facts from capabilities include `hasX11`, `hasWayland`,
`isGraphical`, `hasPortal`, `hasNotifications`, `hasClipboard`, `hasAudio`,
`hasPaper`, `hasVm`, `hasLspmux`, `hasRea`, `defaultBrowser`, `hasFirefox`.

Project and DB “stores” remain encrypted vaults. Refer to them as “secret
stores” or “vaults” to avoid collision with runtime state.

### Storage Choice

Start with JSON files and JSONL logs, not a central database.

Why:

- state is small and per-host
- inspectable and debuggable
- no schema server
- no eval dependency on a mutable DB
- easy atomic writes and ownership
- secrets remain outside state

Add SQLite only if history, queries, or cross-host indexing is required. If
added, it sits behind the same repository port and remains runtime-only.

## Capabilities

### `capabilities/packages`

Owns the catalog and graph:

- scan and validate `catalog/features/`
- scan and validate `catalog/toolchains/`
- scan and validate `catalog/runtime/`
- discover catalogs from directory presence; no static arrays
- sort catalog entries deterministically
- reject duplicate IDs and orphan implementation directories
- validate co-located feature side files with `pipelines/modules`
- resolve profiles
- expand transitive dependencies
- resolve capability providers, including external capabilities
- detect cycles and conflicts
- produce topological order
- produce resolved package values
- produce `SystemPlan` and diagnostics

Public API exposes plain results: entries, profile resolution, `resolve`, and
validation diagnostics.

### `capabilities/context`

Pure context model:

```nix
{
  desired = {
    theme = "miasma";
    profiles = [ "desktop" ];
    packages = [ ];
    requirements = { };
  };

  observed = {
    bootMode = {
      status = "unknown"; # unknown | verified | failed
      value = null;
      evidence = null;
    };
  };

  derived = {
    selected = [ ];
    capabilities = { };
    facts = { };
  };
}
```

Rules:

- `desired` comes from the host declaration and profile selections.
- `observed` is imported from a tracked observation file or supplied by a
  runtime probe.
- `derived` comes from the resolver and host facts.
- Missing observation means `status = "unknown"`, never `false`.
- Required context facts fail closed on `unknown` or `failed`.
- Advisory facts produce diagnostics.
- A stale observation never authorizes a destructive operation.

### `capabilities/platform`

Owns base platform adapters:

- home-manager base module
- NixOS base module
- fonts
- nix-ld compatibility
- nushell bridge
- desktop shadow cleanup
- generic environment integration

No feature-specific logic.

### `capabilities/theme`

Facade over:

- theme schema and loader
- normalized theme values
- contrast helpers
- check helpers used by renderers
- home-manager theme modules
- Gtk and Qt theme adapters

Feature renderers receive theme data through arguments; they do not import
theme internals. Theme-aware outputs are baked by `package.nix` at build
time; there is no separate `render.nix`.

### `capabilities/host`

Owns:

- host discovery
- host declaration normalization
- target observation loading
- context creation
- package selection and resolution
- `mkHome`
- `mkNixos`

Host object gains:

```nix
{
  target = { ... };
  context = { ... };
  packages = [ ... ]; # resolved
  facts = { ... };    # derived capabilities
}
```

Feature modules receive `facts` instead of a global store.

### `capabilities/persistence`

Owns:

- impermanence policy
- persistent path resolution
- feature persistence entries
- ownership checks
- persistence validation

Package records declare `persist` entries. `capabilities/persistence`
interprets them.

### `capabilities/secrets`

Owns:

- secret refs and scopes
- ciphertext presence checks
- decryption and provisioning adapters
- secret repository port
- secret availability observations
- app secret activation
- secret redaction rules

`pipelines/activation` and `capabilities/projects` consume it. No secret values
enter context, state, logs, or package records.

### `capabilities/vm`

Owns:

- VM NixOS modules
- VM state repositories
- VM runtime adapters
- VM lifecycle and MCP server
- `angst-vm` binary

The VM profile and VM runtime are one bounded context.

### `capabilities/projects`

Owns:

- project sync
- DB sync
- vault operations
- FTP mount operations
- encrypted working stores
- project/db state metadata
- `angst-projects` binary

Consumes `capabilities/secrets`. It is not part of CLI composition logic.

## Pipelines

### `pipelines/activation`

Owns the sole phase state machine:

- `angst switch` orchestration
- strict target validation and backend selection
- NixOS and home-manager activation backends
- remote deploy backends
- phase state machine and live progress events
- activation run history and stored logs
- login shell sync
- `angst status`, `angst history`, `angst log`
- legacy `angst-hm-switch` compatibility behavior

`angst switch` is strict:

- requires `target.nix`
- no implicit probe or target write
- no hidden backend default
- no first-host fallback
- no fallback when the selected flake output is missing

It uses target, deploy, state, log, and secret ports. `infra/cli` composes the
binaries; activation owns the behavior.

### `pipelines/modules`

Generic package-to-module engine (the build step of the pipeline):

- pair selected package records with co-located side files and builds
- validate `home.nix`, `system.nix`, `package.nix`, `checks.nix`, `config/`
- invoke `package.nix` per selected package with the host's `theme`,
  `toolchains`, `upstream`, `src`, and git-derived `version`
- select sides for the target
- generate home-manager modules
- generate NixOS modules
- install the built store path; theme-aware outputs come from the build
- validate placement and build contracts

It does not own platform modules. Those live in `capabilities/platform`.
Required sides unsupported by the target fail; optional sides are skipped
with a diagnostic.

## Infra

Generic mechanics. No domain logic, no domain state.

### `infra/monads`

Edge layer described above. Public operations: `pure`, `bind`, `map`,
`ask`, `asks`, `get`, `gets`, `modify`, `tell`, `fail`, `run`.

### `infra/log`

Unified diagnostics and runtime logging.

- Nix facade: `diagnostic`, `event`, `render`, `throwDiagnostics`, `codes`,
  `levels`.
- Go package: `infra/log/go/logger`.
- Shell helper: `angst-log`, a small helper binary or a wrapper to
  `angst log`.
- JSONL canonical format; human renderer for terminals.
- Live phase/state renderer for activation runs.
- `ANGST_LOG_LEVEL`, `ANGST_LOG_FORMAT`, `ANGST_LOG_DIR`.
- Writes to `~/.local/state/angst/logs/`.
- Secret values never enter events; only `SecretRef`.

Backend output is wrapped as `source=nixos-rebuild` or
`source=home-manager` events with level detection as fallback. Raw output is
always preserved in `raw.log`.

### `infra/state`

Generic runtime state infrastructure:

- `ANGST_STATE_DIR` resolution
- atomic JSON writes
- file locks
- schema versions and migrations
- repository support utilities
- ownership and permission checks

It owns no domain state. Context, secrets, VM, activation, projects, and log
own their repositories and use this facade.

### `infra/cli`

Executable composition only. No domain logic.

```text
infra/cli/
  go.mod
  cmd/angst/
  cmd/angst-switch/
  cmd/angst-projects/
  cmd/angst-secrets/
  cmd/angst-vm/
  cmd/angst-shell/
  cmd/angst-analyze/
  cmd/angst-hm-switch/
  cmd/angst-log/
  internal/platform/
  internal/commands/
  wrappers/
```

One Go module, multiple binaries. Shared code lives in `internal/platform` and
bounded-context command packages. Command packages do not import other command
packages. Only `cmd/*` composes them.

| Binary | Owns | Included when |
|---|---|---|
| `angst` | render, watch, probe, screenshot, notify, log | host needs the core CLI |
| `angst-switch` | system switch, backend selection, phase view, history, deploy | `runtime-activation` capability |
| `angst-projects` | projects, db, vault, ftp | project/DB capabilities selected |
| `angst-secrets` | secret provisioning, SSH key provisioning, VPN provisioning | secret provisioning needed |
| `angst-vm` | VM lifecycle, guest operations, MCP server | `runtime-vm` capability only |
| `angst-shell` | shell switcher | shell switching selected |
| `angst-analyze` | repo analysis | dev/CI only |
| `angst-hm-switch` | home-manager activation compatibility wrapper | home-manager target |
| `angst-log` | tiny structured logger for scripts | scripts need logging before the core CLI |

Rules:

- Each binary is a separate derivation or separate Nix output.
- Do not build all commands into one output. The host closure must not contain
  disabled binaries.
- Builders select only the runtime packages required by the resolved host.
- `base` requires `runtime-activation`.
- `vm` profile requires `runtime-vm`. Non-VM hosts get no VM binary, wrapper,
  VM state, or QEMU dependency.
- `projects` bundles require `runtime-projects`.
- Secret provisioning requires `runtime-secrets`.
- `analyze` is dev/CI only.
- `angst-hm-switch` is added by the activation path as a compatibility wrapper.
- `angst switch` never falls back to a hidden default host, target, or backend.
- One binary per bounded context, not one binary per subcommand.
- Thin Nix wrappers preserve legacy names and scope runtime dependencies.

Example wrappers:

```nix
vm = pkgs.writeShellApplication {
  name = "vm";
  runtimeInputs = [ qemu openssh coreutils procps nix age ];
  text = "exec ${runtime.packages.vm}/bin/angst-vm \"$@\"";
};
```

```nix
hm-switch = pkgs.writeShellApplication {
  name = "hm-switch";
  runtimeInputs = [ bash coreutils nix home-manager ];
  text = "exec ${runtime.packages.hmSwitch}/bin/angst-hm-switch \"$@\"";
};
```

### `infra/outputs`

Thin output layer:

- `nixosConfigurations`, only for `target.kind = "nixos"`
- `homeConfigurations`, for every host
- `packages` (built from `catalog/`, despite the catalog rename)
- `apps`, including `switch`, activation, and deploy
- `checks`
- `devShells`
- `formatter`
- `lib` render helpers

`flake.nix` becomes inputs plus `infra/outputs/default.nix`. It owns no
logic; it only exposes what the buckets produce.

### `infra/lib`

Pure shared utilities only:

- imports only `infra/lib/` and nixpkgs lib
- never imports `capabilities/`, `pipelines/`, `catalog/`, or `governance/`
- generic helpers with no domain logic

### `infra/nixpkgs-config.nix`

Single nixpkgs configuration (e.g. `allowUnfree`). Imported by
`infra/outputs`, `pipelines/modules`, and capability builds via args. Never
hardcoded from `catalog/*`. This is the only infra-level config file; it is
not a helper library.

## Governance

### `governance/validation`

Owns cross-bucket validation and nothing else. It executes nothing; it
returns diagnostics.

- architecture import rules plus the ownership × time matrix
- runtime closure and binary gating
- state schemas, freshness, permissions, ownership
- desktop and profile constraints
- activation phase/log schema and run artifacts
- activation strict failure behavior
- secret redaction
- cross-bucket health checks

Feature-specific checks live in `catalog/features/<id>/checks.nix`.
Bucket-specific checks live in `<bucket>/<name>/checks/`.
`governance/validation` aggregates them.

There is no root `checks/` directory. `infra/outputs` exposes the `checks`
flake output.

### Enforced Matrix: `matrix.nix` and `report.nix`

`governance/validation/matrix.nix` encodes the ownership × time matrix as
data: bucket path × phase to role (`O`, `R`, `W`, `X`, `-`). The static
import scanner in `governance/validation/internal/architecture.nix` maps every
tracked `.nix` file to a bucket by path prefix, extracts imports
(`import`, `callPackage`, relative `../`), and compares each edge against the
matrix plus these rules:

- banned roots present fail `ARCH`: `systems/`, `lib/`, `domains/`,
  `modules/`, `checks/`, `runtime/`, `toolchains/`, `themes/`, `packages/`,
  `profiles/`, `hosts/`, `flake/`
- `catalog/*` imports bucket behavior fail `ARCH` (except `infra/lib/`
  helpers)
- `infra/lib/*` imports outside `infra/lib/` plus nixpkgs lib fail `ARCH`
- `infra/monads` imported outside `capabilities/`, `pipelines/`, `infra/`,
  `governance/` fails `ARCH`
- cross-`internal/` imports fail `ARCH`
- phase literals (`resolve|validate|build|activate|verify|finish`) and state
  literals (`pending|running|ok|warn|error|skipped`) outside `pipelines/`,
  `infra/log`, and `governance/` fail `ARCH`
- event `code`/`phase`/`level` schema breaks fail `LOG`/`ARCH`
- missing `catalog/hosts/<host>/target.nix` fails `TGT001`; no or ambiguous
  host fails `TGT002`; unknown kind or pre-build mismatch fails `TGT003`;
  missing selected output fails `ACT002`; missing backend fails `ACT003`
- unknown profile fails `PROF001`; missing package, capability, provider,
  cycle, or conflict fails `PKG`; desktop cardinality and compatibility fail
  `DESK001`, `DESK002`, `DESK003`, or `TGT001`
- disabled `runtime-*` binaries present in a closure fail `ACT`/`ARCH`
- bad permissions (`0700`/`0600`), envelope breaks, stale required facts, or
  secret values instead of `SecretRef` fail `CTX`/`SEC`/`LOG`

`governance/validation/report.nix` collects **all** violations, groups them
by type, orders violations by path within each group, and fails evaluation
once with the full report:

```nix
{ groups = [
  { name = "architecture";
    violations = [
      { code = "ARCH"; path = "..."; expected = "..."; found = "..."; }
    ]; }
  { name = "target"; violations = [ /* ... */ ]; }
  { name = "capabilities"; violations = [ /* ... */ ]; }
  { name = "desktop"; violations = [ /* ... */ ]; }
  { name = "closure"; violations = [ /* ... */ ]; }
  { name = "state"; violations = [ /* ... */ ]; }
  { name = "secrets-log"; violations = [ /* ... */ ]; }
]; }
```

Fatal errors render through `throwDiagnostics`. There is no warn mode: `nix
flake check` stays red until zero violations.

## Catalog Packages

Each feature is exactly one package directory. `catalog/features/` is the new
name for what is currently `domains/`.

```text
catalog/features/wm/i3/
  default.nix
  package.nix
  src/
  home.nix
  system.nix
  checks.nix
  config/
```

`default.nix` is pure package data. `package.nix` is the build. Side files
are Nix module adapters installing the built store path and may import only
local helpers, not bucket code. Theme-aware outputs are baked by
`package.nix` at build time; there is no separate `render.nix`.

`catalog/features/wm/i3/default.nix`:

```nix
{
  type = "window-manager";
  description = "i3 window manager";

  placement.xdg = "i3";

  sides = {
    home = { };
    system = {
      targets = [ "nixos" ];
    };
  };

  provides = {
    window-manager = { session = "x11"; };
  };

  requires = {
    packages = [ "display.x11" "kernel.graphical" ];
    capabilities = [ "x11-session" ];
  };

  conflicts = [ ];
}
```

`catalog/features/git/lazygit/default.nix`:

```nix
{
  type = "development-tool";
  description = "Lazygit TUI";

  placement.xdg = "lazygit";

  sides.home = { };

  requires.packages = [ "git.code" ];
  provides.git-ui = { };
}
```

`catalog/features/git/lazygit/package.nix` is a thin wrapper: it takes
`upstream = pkgs.lazygit`, wraps it with `symlinkJoin` + `wrapProgram`,
bakes the config into `$out`, and sets
`passthru.upstreamVersion = upstream.version`. The wrapper still owns its
config even though the binary comes from nixpkgs.

Build outputs (output attribute `packages` is kept despite the catalog
rename):

- `packages.${system}.<category>-<name>`: built for the representative host
  (its theme + toolchains).
- `packages.${system}."<hostname>--<category>-<name>"`: per-host baked
  variant (that host's theme + toolchains).
- `version` is git-derived in all cases (`self.shortRev` /
  `self.dirtyShortRev`, fallback `"dev"`).

Fields:

- `type`: required classification. Start from categories, refine semantically.
- `targets`: supported target kinds. Defaults to both.
- `sides`: `home`, `system`, or both.
- `sides.home` / `sides.system`: side availability and requirements.
- `sides.system.when`: declarative condition for conditional sides.
- `placement`: `xdg`, `xdgFile`, `customXdg`, `mutable`.
- `requires.packages`: package IDs.
- `requires.capabilities`: capability names.
- `requires.context`: optional context requirements.
- `provides`: capability map with attributes.
- `conflicts`: package IDs.
- `optional`: only after conditional dependencies are modeled.
- `persist`: persistence entries interpreted by `capabilities/persistence`.

Capabilities are maps, not bare lists:

```nix
provides = {
  display-server = { session = "x11"; };
  display-manager = { };
  git = { };
};
```

External capabilities use the same shape in `target.nix`.

### Toolchains

Toolchains live in `catalog/toolchains/`:

```text
catalog/toolchains/
  _builder.nix
  _schema.nix
  rust.nix
  go.nix
```

A toolchain is a declarative spec, not a normal feature package:

- runtime packages
- LSP packages
- formatter/linter packages
- package manager
- tree-sitter grammars
- editor LSP configuration
- capabilities such as `toolchain:rust`, `lsp:rust`

`capabilities/packages` scans, validates, indexes, and resolves toolchains.
`catalog/toolchains/_builder.nix` provides `mkToolchain` as a pure helper.
There is no root `toolchains/` directory.

### Runtime Package Records

Runtime tools live under `catalog/runtime/<tool>/` with a record plus a
build, so the resolver gates binaries and closures:

```nix
# catalog/runtime/vm/default.nix
{
  type = "runtime-tool";
  description = "VM lifecycle and MCP server";

  targets = [ "nixos" ];
  sides.home = { };

  provides.runtime-vm = { };
}
```

```text
catalog/runtime/vm/
  default.nix
  package.nix   # Go build and wrapper
  src/
```

Rules:

- `vm` profile requires `runtime-vm`.
- `base` requires `runtime-angst` and `runtime-activation`.
- `development` and CI require `runtime-analyze`.
- Project bundles require `runtime-projects`.
- Secret provisioning requires `runtime-secrets`.
- `runtime-hm-switch` is compatibility-only; normal activation uses
  `runtime-activation`.
- `runtime-shell` is required only when shell switching is selected.
- No non-VM host receives `runtime-vm`, the `vm` wrapper, VM state, or QEMU.

Do not convert conditional assertions into unconditional dependencies. For
example, `browser.firefox -> display.gpu` stays an assertion until optional or
conditional dependencies exist.

## Catalog Profiles

`catalog/profiles/*.nix` are data, and each file is a graph node.

```nix
# catalog/profiles/desktop.nix
{
  kind = "profile";
  type = "system";

  requires = {
    profiles = [ "base" ];

    packages = [
      "terminal.ghostty"
      "launcher.rofi"
      "kernel.audio"
      "kernel.clipboard"
    ];

    capabilities = [
      { name = "window-manager"; min = 1; max = 1; }
      { name = "display-server"; min = 1; max = 1; }
      { name = "display-manager"; min = 0; max = 1; target = "nixos"; }
    ];
  };

  preferredProviders = {
    display-manager = [ "display.ly" ];
  };

  constraints = [
    {
      kind = "compatible";
      provider = "window-manager";
      with = "display-server";
      via = "session";
    }
  ];
}
```

Profile kinds:

- `type = "system"`: `desktop`, `server`, `vm`.
- `type = "bundle"`: `base`, `development`, `gaming`, `office`, etc.

Rules:

- Profiles are package-graph nodes with `kind = "profile"`.
- Profiles may require packages, capabilities, and other profiles.
- Profiles may declare target support.
- Profiles may declare constraints.
- `systemModules` is the only infrastructure escape hatch, used by the VM
  system profile.
- `base` requires `runtime-angst` and `runtime-activation`.
- `vm` requires `runtime-vm`.
- `development` and CI require `runtime-analyze`.
- The activation path requires `runtime-activation`; `runtime-hm-switch` is
  compatibility-only.
- No flat `enable` lists, no profile ordering, no duplicate package IDs.
- Profiles are discovered by filename; no static `profileMap`.

Hosts may also select explicit package IDs:

```nix
{
  profiles = [ "desktop" "development" ];
  packages = [ "wm.i3" ];
}
```

## Resolver Rules

- Auto-enable transitive package and capability dependencies.
- Merge package providers and external host-OS capabilities.
- Order dependencies before dependents.
- Missing package: error with source ID and dependency path.
- Missing capability: error with requiring ID.
- Multiple providers: error with candidate IDs unless the profile or host
  explicitly selects a provider.
- Cycle: error with the full cycle path.
- Conflict: error with both IDs.
- Deterministic output for a fixed catalog and selection.
- Optional dependencies only when an explicit condition evaluates true.
- Target-specific sides that are unsupported produce diagnostics; required
  sides fail, optional sides are skipped.

## Desktop Check

Desktop constraints live in the graph, not in feature assertions.

Provider examples:

```nix
# catalog/features/display/x11/default.nix
provides = {
  display-server = { session = "x11"; };
};
```

```nix
# catalog/features/wm/i3/default.nix
provides = {
  window-manager = { session = "x11"; };
};
```

```nix
# catalog/features/display/ly/default.nix
targets = [ "nixos" ];
provides = {
  display-manager = { };
};
```

Desktop rules:

- exactly one `window-manager`
- exactly one `display-server` by default
- every selected WM session is provided by a selected display server
- at most one `display-manager`
- display managers are mutually exclusive
- NixOS-only sides fail on `generic-linux`
- external host-OS capabilities count as providers

Hybrid X11 plus Wayland is explicit:

```nix
{ name = "display-server"; min = 1; max = 2; allowHybrid = true; }
```

Diagnostics:

```text
DESK001 desktop: window-manager: expected 1, got 2 (wm.i3, wm.sway)
DESK002 desktop: display-server: wm.sway requires wayland; selected: x11
DESK003 desktop: display-manager: display.lightdm conflicts display.ly
TGT001  desktop: display.ly system side unsupported on target generic-linux
```

`governance/validation` runs the desktop check for every host selecting a system
profile with desktop constraints.

Remove graph-level assertions from feature modules. Keep only assertions for
facts the graph cannot know.

## Unusual Features

| Shape | Model |
|---|---|
| package only | `package.nix` build, no sides |
| home only | `sides.home` |
| system only | `sides.system`, `targets = [ "nixos" ]` |
| both sides | `sides.home` + `sides.system` |
| conditional side | `sides.system.when = { fact = "host.ssh.server.enable"; equals = true; }` |
| custom build | `package.nix` + local `src/`, explicit `theme` / `toolchains` inputs, baked output |
| thin wrapper | `package.nix` with `upstream = pkgs.<name>`, baked config, `passthru.upstreamVersion` |
| custom XDG | `placement.customXdg` |
| mutable config | `placement.mutable` |
| target-specific | `targets = [ "generic-linux" ]` |
| fact-dependent behavior | capabilities plus derived facts |
| feature check | `checks.nix` beside the feature |
| runtime tools | `catalog/runtime/*`, built by `infra/cli`, gated by runtime capabilities |
| host-specific extras | stay `host.extraNixos` / `host.extraHome` |

Examples:

- `display.gpu`: `targets = [ "generic-linux" ]`, home side only.
- `remote.ssh`: home side both targets; system side NixOS and conditional on
  `ssh.server.enable`.
- `network.vpn`: home plus system; system side NixOS.
- `browser.firefox`: home plus system; `display.gpu` remains optional or
  conditional.
- `notifications`: requires `graphical`; backend from display-server
  capabilities.
- `capture.screenshot`: same pattern.
- `wm.i3`: requires X11; optional screenshot/audio/notification bindings based
  on capabilities.
- `agents.opencode`: uses `editorLsp`, `hasLspmux`, `hasPaper`, and `hasRea`
  facts.
- `editor.nvim`: home side, baked config, mutable lockfile.
- `design.paper`: custom `package.nix` build (fetch/wrap AppImage).
- `games.steam`, `kernel.audio`, `kernel.container`: system side NixOS only.

## Logging

One schema for eval diagnostics and runtime events.

```json
{
  "ts": "2026-10-21T12:00:00Z",
  "level": "error",
  "code": "DESK001",
  "scope": "profiles",
  "host": "nixos",
  "profile": "desktop",
  "phase": "resolve",
  "message": "window-manager: expected 1, got 2",
  "data": {
    "providers": ["wm.i3", "wm.sway"]
  }
}
```

Rules:

- Nix evaluation returns diagnostics; it does not print progress traces.
- Fatal evaluation errors render through `throwDiagnostics` as one grouped
  report (see `governance/validation/report.nix`); there is no warn mode.
- Runtime logs go to stderr and `~/.local/state/angst/logs/`.
- JSONL is canonical; the human renderer is a view.
- Stable codes: `TGT`, `PKG`, `PROF`, `DESK`, `CTX`, `SEC`, `VM`, `PROJ`,
  `DEP`, `ACT`, `LOG`, `ARCH`.
- Secret values never enter logs; only `SecretRef`.
- Replace `VERBOSE_ECHO`, raw `echo "==>"`, and ad-hoc progress `fmt.Printf`
  calls.
- `angst-switch` wraps backend output as `source=nixos-rebuild` or
  `source=home-manager` events and keeps level detection as fallback.
- Activation events include phase and state transitions.
- The old `runtime/logger` seeds the shared Go logger under `infra/log`.
- State and logs share `ANGST_STATE_DIR`; activation runs live under
  `~/.local/state/angst/activation/`; VM state lives under
  `~/.local/state/angst/vm/`.

## Migration Phases

### Phase 0: Baseline

```bash
NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure
just go-test
```

Record per-host enabled/package sets and rendered output hashes.

### Phase 1: Infra edge, logging, state, helpers

- Move `lib/` to `infra/lib/`; keep helpers pure (imports only
  `infra/lib/` plus nixpkgs lib).
- Move `lib/nixpkgs-config.nix` to `infra/nixpkgs-config.nix` as the single
  configuration. No root-level exceptions.
- Implement `infra/monads` with ports, interpreters, and central tests.
- Add `infra/log` schema and diagnostics renderer.
- Add `infra/state` contracts.
- No production callers yet.
- Verify with `nix flake check --no-build --impure`.

### Phase 2: Target and context

- Add generated `catalog/hosts/<host>/target.nix` schema.
- Add explicit `angst host detect`.
- Add external capabilities to target observations.
- Add state schema versions, freshness, and atomic update rules.
- Add `capabilities/context` desired/observed/derived model.
- Add activation/deploy apps that choose backend from target kind.
- Missing target -> flake emits home config only plus `TGT001`.
- `angst switch` fails `TGT001` on missing target; no probe, no write, no
  fallback.
- Verify no flake evaluation reads the live machine.

### Phase 3: Catalog, features, toolchains, profiles

- Move `domains/<cat>/<name>/` into `catalog/features/<cat>/<name>/`.
- Move `default.nix` metadata into the package directory.
- Move `toolchains/*.nix` into `catalog/toolchains/`.
- Move `lib/toolchain.nix` to `catalog/toolchains/_builder.nix`.
- Add `catalog/toolchains/_schema.nix`.
- Move `hosts/*` into `catalog/hosts/`, `profiles/*` into
  `catalog/profiles/`.
- Convert `catalog/profiles/*.nix` to graph profile nodes.
- Remove the static `profileMap`; discover profiles by filename.
- Move profile resolution into `capabilities/packages`.
- Add directory scanners for features, toolchains, runtime tools, and profiles.
- Add scanner tests: deterministic order, duplicate IDs, orphan dirs, invalid
  entries, skipped `_*` files.
- Add sides, targets, and conditional side schema.
- Add graph tests: closure, cycle, missing package, missing capability,
  ambiguous provider, conflicts, ordering, target support.
- Run resolver in diagnostics-only mode and compare selected sets.
- Enable auto-closure.
- Convert explicit assertions to `requires`/`conflicts`.
- Replace the old store helper with derived facts (`hasX11`, `hasWayland`,
  `isGraphical`, ...).
- Verify every host still evaluates.

### Phase 4: Desktop constraints and feature checks

- Add capability cardinality and compatibility checks.
- Add desktop validation.
- Move feature-specific checks beside features as `checks.nix`.
- Add fixture tests for one WM/server, duplicates, incompatibility, external
  providers, and generic-Linux target sides.
- Verify desktop profiles on NixOS and generic-Linux fixtures.

### Phase 5: Buckets split and pipeline modules

- Move package-to-module pairing into `pipelines/modules` (per-selected-package
  `package.nix` invocation with host `theme` + `toolchains`).
- Move base home/NixOS modules to `capabilities/platform`.
- Move theme/Gtk/Qt modules to `capabilities/theme`.
- Move login shell to `pipelines/activation`.
- Move app secret support to `capabilities/secrets`.
- Move impermanence policy to `capabilities/persistence`.
- Move persistence record data into feature package records.
- Move VM modules and VM runtime code to `capabilities/vm`.
- Move project/db/vault/FTP runtime code to `capabilities/projects`.
- Move tree-sitter adapter to `capabilities/packages`.
- Delete root `modules/`.
- Compare built store-path config hashes before and after.

### Phase 6: Host and outputs

- Move host discovery, normalization, `mkHome`, and `mkNixos` into
  `capabilities/host`.
- Move flake wiring into `infra/outputs`.
- Make `flake.nix` import only `infra/outputs`.
- Emit `nixosConfigurations` only for `target.kind = "nixos"`.
- Preserve all public output names (including the `packages` attribute, built
  from `catalog/`).
- Keep shared catalog and toolchain caching for `x86_64-linux`.

### Phase 7: CLI, binaries, state

- Remove top-level `runtime/`.
- Move Go sources to `infra/cli` as one Go module.
- Split binaries by bounded context:
  `angst`, `angst-switch`, `angst-projects`, `angst-secrets`, `angst-vm`,
  `angst-shell`, `angst-analyze`, `angst-hm-switch`, `angst-log`.
- Build each binary as a separate derivation or separate Nix output. Never
  build all commands into one host closure.
- Preserve legacy names with thin wrappers:
  `vm`, `angst-shell`, `analyze`, `hm-switch`, `nixos-switch`.
- Move Nix activation glue to `infra/cli/wrappers/` or
  `infra/cli/internal/`.
- Move each Go tool build into its owning `catalog/runtime/<tool>/`
  (`default.nix` record plus `package.nix` build plus `src/`); no separate
  recipe directory.
- Gate binaries through runtime capabilities.
- Move `domains/design/paper/package.nix` to
  `catalog/features/design/paper/package.nix` and fold the wrapper flags
  into the same build.
- Bake the tree-sitter grammar set into the owning feature package build
  (via the `toolchains` input).
- Wire adapters in context, secrets, VM, activation, projects, and log.
- Add `infra/state` with atomic writes, locks, schema versions, and
  `ANGST_STATE_DIR`.
- Implement `pipelines/activation`:
  - strict target validation
  - automatic backend selection from `target.kind`
  - phase state machine
  - live phase renderer
  - `angst status`, `history`, `log`
  - per-run artifacts under `state/activation/<host>/<run-id>/`
- Move `switch-*` logs, VM state, activation state, and project/db sidecars
  into the unified state layout.
- Replace ad-hoc script output with `angst-log`.
- Update `go.work`/module paths, `justfile`, CI workflow, and health check
  paths.
- Verify Go tests, each runtime binary, activation logs, and runtime closure
  gating.

### Phase 8: Governance, enforcement, docs

Land `governance/validation` with the enforced matrix:

- `governance/validation/matrix.nix`: bucket path × phase to role
- `governance/validation/internal/architecture.nix`: static import scan
- `governance/validation/report.nix`: collect-all grouped report, single
  `throwDiagnostics` failure

Enforced rules:

- no `infra/monads` outside `capabilities/`, `pipelines/`, `infra/`,
  `governance/`
- no `*/internal/` outside its own bucket member
- no bucket-behavior imports from `catalog/*` (except `infra/lib/` helpers)
- no imports inside `catalog/features/*/default.nix` or
  `catalog/profiles/` beyond local files and `infra/lib/`
- every bucket member has `default.nix`
- no root `systems/`, `lib/`, `domains/`, `modules/`, `checks/`,
  `runtime/`, `toolchains/`, `themes/`, `packages/`, `profiles/`,
  `hosts/`, or `flake/`
- no single all-features runtime command binary
- runtime state files are not tracked in git, except explicit `target.nix`,
  `hardware.nix`, and `observations.nix`
- state files have schema versions and owners; no cross-bucket state paths

Add `governance/validation` checks for runtime closure, state, desktop,
activation (strict failures, phases, logs, history, redaction), and catalog
discovery (deterministic order, duplicate IDs, orphan directories, invalid
entries).

Update README, `justfile`, CI paths, and OpenWiki source docs. Do not hand-edit
generated OpenWiki pages; regenerate them.

## Verification Gates

After each phase:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure
```

Final gates:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure
NIXPKGS_ALLOW_UNFREE=1 nix build .#checks.x86_64-linux.build-all --impure
NIXPKGS_ALLOW_UNFREE=1 nix build .#checks.x86_64-linux.runtime-closure --impure
NIXPKGS_ALLOW_UNFREE=1 nix build .#checks.x86_64-linux.state --impure
NIXPKGS_ALLOW_UNFREE=1 nix build .#checks.x86_64-linux.catalog --impure
NIXPKGS_ALLOW_UNFREE=1 nix build .#checks.x86_64-linux.activation --impure
NIXPKGS_ALLOW_UNFREE=1 nix build .#nixosConfigurations.nixos.config.system.build.toplevel --impure
NIXPKGS_ALLOW_UNFREE=1 nix build .#homeConfigurations.nixos.activationPackage --impure
nix run .#render -- --host nixos --no-reload
nix run .#switch -- --dry-run --host nixos
nix run .#status
nix run .#log -- list
just go-fmt
just go-test
```

Additional checks:

- all hosts resolve with closed dependency sets
- every profile ID exists in `catalog/features/` or `catalog/profiles/`
- catalog scanners produce deterministic sorted entries
- no manual feature/toolchain/runtime/profile arrays exist
- every feature directory has `default.nix`
- every toolchain/profile file validates
- `_*` and `default.nix` catalog files are skipped
- duplicate catalog IDs and orphan implementation directories fail
- no cycles, conflicts, or ambiguous providers in any host
- desktop check passes for every host with a desktop system profile
- generic-Linux hosts produce no NixOS outputs
- unknown targets produce home config only plus `TGT001`
- non-VM host closure excludes `angst-vm`, the `vm` wrapper, VM state, and
  QEMU
- non-project host closure excludes `angst-projects`
- secret provisioning absent when `angst-secrets` is not selected
- non-dev host closure excludes `angst-analyze`
- home-manager targets include `angst-hm-switch`
- VM hosts include `angst-vm`
- each runtime binary has only its declared runtime inputs
- `angst switch` fails `TGT001` on missing target, with no probe or write
- `angst switch` fails `TGT002` on missing or ambiguous host
- `angst switch` selects backend only from `target.kind`
- activation phase/state transitions and live renderer output are valid
- activation run artifacts persist `summary.json`, `events.jsonl`, and
  `raw.log`
- activation locks prevent concurrent runs
- activation retention and gzip behavior work
- legacy `hm-switch` and `nixos-switch` wrappers are compatibility-only
- core `angst` does not import project, secret, VM, activation, analyze, or
  hm-switch command packages
- state schemas, freshness, permissions, and ownership are valid
- state files and logs contain no secret values
- feature checks are co-located and aggregated
- built store-path config hashes unchanged after structural moves
- no catalog module imports bucket internals
- context tests prove unknown is distinct from false
- log tests prove secret values are redacted
- matrix violations fail grouped collect-all with zero warn mode

## Risks

1. Auto-enabling dependencies changes package sets. Use the diagnostics-only
   phase and diff before enabling closure.
2. Conditional dependencies must not become unconditional. Keep assertions
   until optional dependencies exist.
3. Target detection requires a tracked observation. Missing manifests must not
   silently produce NixOS outputs.
4. Moving Go sources into one module breaks `go.work` and CI. Update module
   paths and remove `go.work` in the same commit.
5. Moving feature metadata into co-located package directories is a large
   diff. Use scripted `git mv`; do one cutover.
6. Static architecture checks cannot catch dynamic imports. Document the
   limitation and keep facades simple.
7. Never let stale observations authorize destructive operations. Require a
   fresh probe.
8. Unified logging must not leak secrets. Log references and metadata only.
9. A single all-features runtime binary couples optional code into every host.
   Enforce separate binaries and closure checks.
10. State sprawl causes ownership conflicts. Enforce one owner per state file,
    atomic writes, locks, and schema versions.
11. A shared Go module can erode command boundaries. Command packages must not
    import other command packages; only `cmd/*` composes them.
12. State and secret stores must not converge. Keep encrypted secrets outside
    runtime state and never store secret values in state or logs.
13. Splitting base modules by bucket creates duplication risk.
    Keep shared platform adapters in `capabilities/platform`; keep
    feature-specific modules in catalog package directories.
14. `angst switch` must never invent a host, target, or backend. Missing state
    is an error, not an opportunity for fallback.
15. Backend phase boundaries may be inferred from text output. Preserve raw
    logs and never present inferred phases as exact backend internals.
16. Activation logs can grow quickly. Enforce retention, gzip old raw logs, and
    per-host locks.
17. Catalog discovery only sees tracked files. Untracked features, toolchains,
    and themes are invisible until `git add`.
18. Directory discovery can hide typos or duplicates. Validate IDs, reject
    orphan implementation directories, and sort entries deterministically.
19. Do not discover code buckets, adapters, binaries, or validation modules.
    Keep code composition explicit; discovery is for data catalogs.

## Non-Goals

- No runtime probing during flake evaluation.
- No mutable context store.
- No central mutable state database used as flake input.
- No Nix derivation used as a database.
- No monad access outside `capabilities/`, `pipelines/`, `infra/`,
  `governance/`.
- No single all-features runtime binary.
- No runtime binary or wrapper for a disabled capability.
- No manual theme/toolchain/feature/profile catalog arrays.
- No runtime filesystem discovery for build catalogs.
- No implicit target detection or target write in `angst switch`.
- No hidden backend fallback when the target manifest or selected output is
  missing.
- No shared `systems/` label across buckets that differ widely.
- No root `systems/`, `lib/`, `domains/`, `modules/`, `checks/`,
  `runtime/`, `toolchains/`, `themes/`, `packages/`, `profiles/`,
  `hosts/`, or `flake/` directory.
- No NixOS configuration output for `generic-linux` targets.
- No implicit deployment of a NixOS closure to a non-NixOS host.
