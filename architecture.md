# angst architecture

Proposed architecture. Current code is still on the old layout; this document
defines the target and the migration path.

## Goals

- `systems/` contains bounded contexts and framework systems.
- `systems/monads/` is the edge: ports, interpreters, effect composition, and
  one central test suite.
- `packages/` contains self-contained feature derivations, toolchain specs,
  and runtime tool builds. Each package directory is a real Nix package:
  `src/` lives inside it, inputs (`theme`, `toolchains`) are explicit
  function arguments, and theme/toolchain values are baked into the store
  output.
- Feature implementations are co-located with their package builds.
- `features/` is the new name for what is currently `domains/`: the unit of
  configuration, moved under `packages/` as
  `packages/features/<category>/<name>/`.
- Package versions are git-derived (flake `self.shortRev` /
  `self.dirtyShortRev`, fallback `"dev"`); no hardcoded versions.
- No separate `derivations/` directory. Shared build helpers are consumed via
  `callPackage` dependencies, not via a shared recipe directory.
- `lib/` contains only shared utilities.
- Profiles are graph nodes with requirements and constraints.
- Systems are the only modules allowed to import `systems/monads`.
- Every system exposes a narrow facade; internal modules are private.
- Target identity and runtime state are observed, not declared in the host.
- Host context distinguishes desired, observed, and derived data.
- Runtime probing and deployment stay outside flake evaluation.
- All runtime output uses one structured logging system.
- `angst switch` is the only system-activation entry point. It selects the
  backend from tracked target state, never from a hidden default, and records
  structured phase/log artifacts.
- Runtime executables are separate opt-in artifacts, not one all-features
  binary.
- No root `domains/`, `modules/`, `checks/`, `runtime/`, `toolchains/`, or
  `flake/` directories.

## Bounded Contexts

| Context | Responsibility |
|---|---|
| Host | Host identity, desired configuration, target reference, secret refs, VM spec |
| Catalog | Feature packages, toolchains, runtime tools, sides, sources, capabilities |
| Profiles | System and bundle profiles, requirements, constraints |
| Resolution | Dependency closure, provider selection, `SystemPlan` |
| Observation | Target identity, external capabilities, hardware, disk/boot facts, freshness |
| Platform | Base home-manager and NixOS modules, fonts, environment integration |
| Theme | Theme loading, validation, Gtk/Qt theme adapters |
| Activation | System switch orchestration, backend selection, phase observability, deploy, login shell, activation history |
| Persistence | Impermanence policy, persistent paths, ownership |
| Secrets | Secret refs, scopes, ciphertext checks, provisioning, redaction |
| VM | VM modules, VM state, VM adapters, VM lifecycle |
| Projects | Project/db/vault sync, working stores, project state |
| CLI | Executable composition, separate binaries, thin wrappers |
| Validation | Cross-system checks, architecture, runtime closure, state |
| Outputs | Flake outputs, apps, checks, devshells |
| Observability | Diagnostics, events, sinks, stable codes |
| State | State root, atomic storage, locks, schema versions, repository support |

NixOS and home-manager modules are adapters at the edge. They receive plain
facts and modules. They never see monads.

## Root Layout

```text
flake.nix
hosts/
profiles/
packages/
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

secrets/                     # encrypted data only

systems/
  monads/
  log/
  state/
  theme/
  packages/
  context/
  modules/
  platform/
  activation/
  persistence/
  secrets/
  vm/
  projects/
  cli/
  host/
  validation/
  outputs/

lib/
githooks/
.github/
```

Removed root directories:

- `domains/`
- `modules/`
- `checks/`
- `runtime/`
- `toolchains/`
- `flake/`

`nixpkgs-config.nix` lives at the repository root, outside `lib/`.

## Packages are derivations

One directory is one derivation. There is no separate `derivations/`
directory and no `source.kind` indirection:

- `packages/features/<category>/<name>/` holds the record (`default.nix`),
  the build (`package.nix` + `src/`), and the adapters (`home.nix`,
  `system.nix`, `config/`, `checks.nix`).
- `packages/runtime/<tool>/` holds the record (`default.nix`) and the build
  (`package.nix` + `src/`) for each runtime binary.
- `packages/toolchains/` holds declarative toolchain specs; `mkToolchain`
  stays a pure helper there, not a derivation.

Flow:

```text
host
  -> profiles
  -> package graph
  -> selected package
       -> packages/features/<category>/<name>/package.nix
            (theme + toolchains baked in)
            -> Nix store path
  -> systems/modules
       -> home-manager / NixOS modules install the built store path
       -> rendered config outputs come from the build, not eval text
  -> systems/host
       -> final system
```

Rules:

- each feature directory is exactly one derivation; each runtime tool
  directory is exactly one derivation.
- `package.nix` takes explicit inputs only; never reads `host`, profiles,
  capabilities, or other packages.
- packages never import `systems/`.
- shared build helpers are consumed via `callPackage` dependencies, not via
  a shared recipe directory.
- feature side files (`home.nix`, `system.nix`) are adapters that install the
  built store path; they are not derivations themselves.

### Self-contained feature packages

Each feature directory ships its own build as a real Nix package.
The package stays self-contained: `src/` lives inside the package directory
and all inputs are explicit function arguments. Theme and toolchain values
are baked into the store output at build time, not rendered as eval text.

```nix
# packages/features/<category>/<name>/package.nix
{ lib, stdenv, theme, toolchains, src, upstream, version }:
stdenv.mkDerivation {
  pname = "<name>";
  inherit src version;
  nativeBuildInputs = [ ];
  buildPhase = ''...'';
  installPhase = ''mkdir -p $out/...; cp -r ... $out/...'';
}
```

Rules:

- `package.nix` is a function; its arguments are its only inputs.
- allowed inputs are nixpkgs build inputs (`lib`, `stdenv`, compilers) plus
  declared domain inputs: `theme`, `toolchains`, `src`, `upstream`,
  `version`, derived facts.
- `src` is the package-local directory (`./src`); the package never reaches
  outside its own directory.
- `theme` is the normalized value from `systems/theme` (`palette`, `ansi`,
  `isDark`, contrast helpers), not theme internals. It is baked into the
  output (for example a generated `palette` file or prompt config).
- `toolchains` is the list of full `mkToolchain` outputs selected for the
  host (`home.packages`, `toolchains.treesitterGrammars`,
  `toolchains.editor.lsp`); the package picks what it needs, the resolver
  decides the selection. Bake derived values in (for example enabled adapter
  lists, grammar sets).
- `version` is git-derived, resolved once by the caller from flake `self`
  (`self.shortRev` / `self.dirtyShortRev`, fallback `"dev"`). No hardcoded
  versions in `package.nix`.
- `upstream` is set only for thin wrappers over nixpkgs binaries (see below);
  custom builds omit it.
- the caller (`systems/packages` via `systems/outputs`) resolves `theme`,
  `toolchains`, `upstream`, `src`, and `version` from host context and
  invokes `package.nix` with `callPackage`-style argument filtering, so each
  package declares only the inputs it uses.
- the build output lands in `packages.${system}.<category>-<name>` and enters
  a host closure only when the package is selected. Per-host baked variants
  are exposed as
  `packages.${system}."<hostname>--<category>-<name>"` aliases.

Thin wrappers over nixpkgs binaries still get a `package.nix`. A wrapper
declares `upstream = pkgs.<name>`, pins no source of its own, wraps via
`symlinkJoin` + `wrapProgram`/`makeWrapper`, and bakes its config into
`$out` alongside the wrapped binary:

```nix
# packages/features/git/lazygit/package.nix
{ lib, stdenv, symlinkJoin, makeWrapper, upstream, theme, version }:
symlinkJoin {
  name = "lazygit-${version}";
  paths = [ upstream ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    # bake config under $out, wrap $out/bin/<name> with --add-flags/--set
  '';
  passthru.upstreamVersion = upstream.version;
}
```

Examples:

| Path | Role |
|---|---|
| `packages/features/wm/i3/default.nix` | package record; graph requirements |
| `packages/features/wm/i3/package.nix` | derivation; builds helper scripts + baked bindings |
| `packages/features/design/paper/package.nix` | derivation; fetch/wrap AppImage + baked flags |
| `packages/features/git/lazygit/package.nix` | thin wrapper over `pkgs.lazygit` + baked config |
| `packages/features/terminal/ghostty/package.nix` | thin wrapper over `pkgs.ghostty` + baked config |
| `packages/runtime/vm/default.nix` | runtime tool record; gating capability |
| `packages/runtime/vm/package.nix` | Go build and wrapper |
| `packages/toolchains/rust.nix` | toolchain bundle spec |

`mkToolchain` is a pure helper, not a derivation. It lives with toolchain
specs.

## Catalog Discovery

Nix evaluation is pure. `builtins.readDir` is **eval-time source discovery**,
not runtime probing. It is deterministic for a fixed tracked source tree, works
offline, and never inspects the target machine.

Use eval-time discovery for declarative catalogs:

| Catalog | Declaration |
|---|---|
| Themes | file under `systems/theme/themes/` |
| Toolchains | file under `packages/toolchains/` |
| Features | directory under `packages/features/<category>/<name>/` |
| Runtime tools | file under `packages/runtime/` |
| Profiles | file under `profiles/` |
| Hosts | directory under `hosts/` with `default.nix` |
| Feature checks | `checks.nix` inside the feature directory |

Use explicit imports for code composition:

| Code | Why explicit |
|---|---|
| `systems/*` | dependency direction and facade ownership |
| NixOS/home-manager adapters | module composition and ordering |
| `systems/cli` command registry | binaries and runtime capabilities |
| `systems/monads` ports/interpreters | contracts and test doubles |
| `systems/outputs` | public flake surface |
| `package.nix` builds | invoked per selected package with explicit args, not global discovery |
| Cross-system validation | explicit public-facade imports |

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
packages/toolchains/
  _builder.nix          # mkToolchain helper, skipped by scanner
  _schema.nix           # toolchain spec validation
  rust.nix
  go.nix

systems/packages/internal/
  toolchains.nix        # scan, validate, index, resolve
```

Flow:

```text
packages/toolchains/*.nix
  -> systems/packages scan
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
- toolchain specs do not import `systems/`
- `mkToolchain` stays a pure helper; it is not a package build

### Features Like Themes

```text
packages/features/<category>/<name>/default.nix
  -> scan
  -> derive ID `category.name`
  -> validate package schema
  -> pair with side files
  -> index
```

Single-level feature:

```text
packages/features/notifications/default.nix
  -> id `notifications`
```

Rules:

- directory with `default.nix` is a feature
- directory without `default.nix` is an error
- side files are optional
- skip `_*` and `config/` internals
- no central feature list
- no manual `entries` array
- `systems/modules` pairs selected entries with side files

### Profiles Like Themes

Remove the static `profileMap`.

```text
profiles/*.nix
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
- system checks are explicitly registered by `systems/validation`
- cross-system checks are explicit imports

Feature checks are data-adjacent and co-located. System checks are code with
dependencies and must not appear by accident.

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
  -> systems/outputs
       -> systems/host
       -> systems/validation
       -> systems/cli
       -> systems/theme
       -> systems/log
       -> packages/
       -> profiles/
       -> lib/

systems/host
  -> systems/packages
  -> systems/context
  -> systems/modules
  -> systems/platform
  -> systems/activation
  -> systems/persistence
  -> systems/secrets
  -> systems/vm
  -> systems/projects
  -> systems/theme

systems/cli
  -> systems/activation
  -> systems/persistence
  -> systems/secrets
  -> systems/vm
  -> systems/projects
  -> systems/state
  -> systems/log

systems/validation
  -> public facades only

systems/*
  -> systems/monads (systems only)
```

Rules:

| Area | Rule |
|---|---|
| `systems/monads` | The edge. Imported only by files under `systems/`. Never imported by packages, profiles, hosts, or secrets. |
| `systems/*/default.nix` | Public API only. Returns plain data, modules, packages, diagnostics, or monadic programs for systems. Never leaks internals. |
| `systems/*/internal/` | Private to that system. No other module may import it. |
| `lib/` | Imports only `lib/` and nixpkgs lib. Never imports `systems/`, `packages/`, or `profiles/`. |
| `packages/features/*/default.nix` | Pure package data. No imports from `systems/`; no executable logic. |
| `packages/features/*/package.nix` | Pure build function. Explicit inputs only (`theme`, `toolchains`, `src`, `upstream`, `version`, nixpkgs inputs); no imports from `systems/`; never reads `host` or profiles. |
| `packages/features/*/{home,system}.nix` | Nix module adapters installing the built store path. Local imports only; no imports from `systems/`. |
| `packages/toolchains/` | Declarative toolchain specs. Local `_builder.nix`/`_schema.nix` imports only; no imports from `systems/`. |
| `packages/runtime/` | Runtime tool records plus `package.nix` builds. No imports from `systems/`. |
| `profiles/` | Pure graph data. No imports from `systems/`; no executable logic. |
| `secrets/` | Encrypted data only. No code. |
| `hosts/` | Pure desired data plus generated tracked observations. No code. |

Architecture checks enforce these rules with a static import scan. Dynamic
imports cannot be fully checked; keep facades simple.

## The Edge: `systems/monads`

`systems/monads/` is not a private helper. It is the effect boundary and the
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
| `Target` | fixed `Nixos` / `GenericLinux` / `Unknown` | reads tracked `target.nix` | `systems/context` |
| `Observations` | fixture facts | reads tracked `observations.nix` | `systems/context` |
| `Secrets` | fake refs | checks ciphertext presence | `systems/secrets` |
| `VM` | fake lifecycle | none | `systems/vm` |
| `Deploy` | plan only | plan only | `systems/activation` |
| `Projects` | fixture stores | tracked metadata only | `systems/projects` |
| `Log` | captured events | diagnostics only | `systems/log` |
| `State` repositories | in-memory stores | tracked snapshots | `systems/state` plus owning system |

Systems do not call `os.ReadFile`, SSH, QEMU, or `nixos-rebuild` directly. They
call ports. Adapters in the owning systems perform the effects.

`systems/monads/interpreters/runtime.nix` is a factory that receives an adapter
record. It does not implement OS effects itself.

### Testing

All monad tests live under `systems/monads/tests/`:

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

Consumer systems use the same fixture interpreters. Unit tests do no
filesystem, network, VM, or SSH work. `systems/validation` runs end-to-end repo
checks.

## Target Model

Pure Nix cannot detect the target OS. `builtins.currentSystem` is the evaluator
platform, not the target. A remote host is invisible to evaluation.

Use a generated, tracked target manifest:

```nix
# hosts/<domain>/<host>/target.nix
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

`systems/activation` builds the deployment plan. `systems/cli` executes it.

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

- desired: `hosts/**/default.nix`, `profiles/`, `packages/`
- stable observed: `hosts/<host>/target.nix`, `hosts/<host>/hardware.nix`
- optional tracked observations required at build time:
  `hosts/<host>/observations.nix`
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
| Host desired config | desired | Host | `hosts/<host>/default.nix` | yes |
| Target identity | observed stable | Context | `hosts/<host>/target.nix` | yes |
| External capabilities | observed stable | Context | `target.nix` | yes |
| Hardware | observed stable | Context | `hosts/<host>/hardware.nix` | yes |
| Install/disk/boot probes | observed volatile | Context | tracked `observations.nix`, or runtime state | only if imported |
| Profiles/packages | desired | Packages | `profiles/`, `packages/` | yes |
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
| `TargetRepository` | tracked `hosts/<host>/target.nix` | `systems/context` |
| `HardwareRepository` | tracked `hosts/<host>/hardware.nix` | `systems/context` |
| `ObservationRepository` | tracked snapshots or `state/observations/` | `systems/context` |
| `SecretRepository` | `secrets/**/*.age` plus runtime decrypted material | `systems/secrets` |
| `VmStateRepository` | `state/vm/services/*.json` | `systems/vm` |
| `ActivationRepository` | `state/activation/<host>/<run-id>/` | `systems/activation` |
| `ProjectStateRepository` | `state/projects/` plus working store | `systems/projects` |
| `DbStateRepository` | `state/db/` plus decrypted DB store | `systems/projects` |
| `LogRepository` | `state/logs/` | `systems/log` |

Ports live in `systems/monads/ports/`. Production adapters live in the owning
system. Test adapters are in-memory or fixture-backed.

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

| System | State ownership |
|---|---|
| `systems/context` | target, hardware, observations |
| `systems/secrets` | secret refs, availability, provisioning metadata |
| `systems/vm` | VM service state, VM logs, VM locks |
| `systems/activation` | system switch runs, deploy runs, activation history, logs |
| `systems/projects` | project/db/vault sync metadata and working-store state |
| `systems/log` | append-only logs |
| `systems/state` | state root, atomic IO, locks, schema versions |
| `systems/cli` | no state ownership; composes binaries |

Rules:

- one owner per state file
- no cross-system writes
- shared state mechanics live in `systems/state`
- append-only logs
- no secret values in state files or logs

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
- `systems/secrets` owns provisioning. `systems/activation` consumes it.

### `lib/store.nix`

Delete it. It is not a state store.

Replace it with:

- `systems/context` desired/observed/derived context
- `systems/packages` capability providers and derived facts
- feature modules receive `facts` instead of `store`

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

## Systems

### `systems/monads`

Edge layer described above. Public operations for systems: `pure`, `bind`,
`map`, `ask`, `asks`, `get`, `gets`, `modify`, `tell`, `fail`, `run`.

### `systems/log`

Unified diagnostics and runtime logging.

- Nix facade: `diagnostic`, `event`, `render`, `throwDiagnostics`, `codes`,
  `levels`.
- Go package: `systems/log/go/logger`.
- Shell helper: `angst-log`, a small helper binary or a wrapper to
  `angst log`.
- JSONL canonical format; human renderer for terminals.
- Live phase/state renderer for activation runs.
- `ANGST_LOG_LEVEL`, `ANGST_LOG_FORMAT`, `ANGST_LOG_DIR`.
- Writes to `~/.local/state/angst/logs/`.
- Secret values never enter events; only `SecretRef`.

### `systems/state`

Generic runtime state infrastructure:

- `ANGST_STATE_DIR` resolution
- atomic JSON writes
- file locks
- schema versions and migrations
- repository support utilities
- ownership and permission checks

It owns no domain state. Context, secrets, VM, activation, projects, and log
own their repositories and use this facade.

### `systems/theme`

Facade over:

- theme schema and loader
- normalized theme values
- contrast helpers
- check helpers used by renderers
- home-manager theme modules
- Gtk and Qt theme adapters

Feature renderers receive theme data through arguments; they do not import
theme internals.

### `systems/packages`

Owns the catalog and graph:

- scan and validate `packages/features/`
- scan and validate `packages/toolchains/`
- scan and validate `packages/runtime/`
- discover catalogs from directory presence; no static arrays
- sort catalog entries deterministically
- reject duplicate IDs and orphan implementation directories
- validate co-located feature side files with `systems/modules`
- resolve profiles
- expand transitive dependencies
- resolve capability providers, including external capabilities
- detect cycles and conflicts
- produce topological order
- produce resolved package values
- produce `SystemPlan` and diagnostics

Public API exposes plain results: entries, profile resolution, `resolve`, and
validation diagnostics.

### `systems/context`

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

### `systems/modules`

Generic package-to-module engine:

- pair selected package records with co-located side files and builds
- validate `home.nix`, `system.nix`, `package.nix`, `checks.nix`, `config/`
- invoke `package.nix` per selected package with the host's `theme`,
  `toolchains`, `upstream`, `src`, and git-derived `version`
- select sides for the target
- generate home-manager modules
- generate NixOS modules
- install the built store path; theme-aware outputs come from the build
- validate placement and build contracts

It does not own platform modules. Those live in their bounded contexts.

### `systems/platform`

Owns base platform adapters:

- home-manager base module
- NixOS base module
- fonts
- nix-ld compatibility
- nushell bridge
- desktop shadow cleanup
- generic environment integration

No feature-specific logic.

### `systems/activation`

Owns:

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

It uses target, deploy, state, log, and secret ports. `systems/cli` composes the
binaries; activation owns the behavior.

### `systems/persistence`

Owns:

- impermanence policy
- persistent path resolution
- feature persistence entries
- ownership checks
- persistence validation

Package records declare `persist` entries. `systems/persistence` interprets
them.

### `systems/secrets`

Owns:

- secret refs and scopes
- ciphertext presence checks
- decryption and provisioning adapters
- secret repository port
- secret availability observations
- app secret activation
- secret redaction rules

`systems/activation` and `systems/projects` consume it. No secret values enter
context, state, logs, or package records.

### `systems/vm`

Owns:

- VM NixOS modules
- VM state repositories
- VM runtime adapters
- VM lifecycle and MCP server
- `angst-vm` binary

The VM profile and VM runtime are one bounded context.

### `systems/projects`

Owns:

- project sync
- DB sync
- vault operations
- FTP mount operations
- encrypted working stores
- project/db state metadata
- `angst-projects` binary

Consumes `systems/secrets`. It is not part of CLI composition logic.

### `systems/cli`

Executable composition only. No domain logic.

```text
systems/cli/
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

### `systems/host`

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

`lib/store.nix` is removed. Feature modules receive `facts` instead of `store`.

### `systems/validation`

Owns cross-system validation:

- architecture import rules
- runtime closure and binary gating
- state schemas, freshness, permissions, ownership
- desktop and profile constraints
- activation phase/log schema and run artifacts
- activation strict failure behavior
- secret redaction
- cross-system health checks

Feature-specific checks live in `packages/features/<id>/checks.nix`.
System-specific checks live in `systems/<name>/checks/`.
`systems/validation` aggregates them.

Root `checks/` disappears. `systems/outputs` exposes the `checks` flake output.

### `systems/outputs`

Thin output layer:

- `nixosConfigurations`, only for `target.kind = "nixos"`
- `homeConfigurations`, for every host
- `packages`
- `apps`, including `switch`, activation, and deploy
- `checks`
- `devShells`
- `formatter`
- `lib` render helpers

`flake.nix` becomes inputs plus `systems/outputs/default.nix`.

## Packages

Each feature is exactly one package directory. `features/` is the new name
for what is currently `domains/`.

```text
packages/features/wm/i3/
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
local helpers, not `systems/`. Theme-aware outputs are baked by
`package.nix` at build time; there is no separate `render.nix`.

`packages/features/wm/i3/default.nix`:

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

`packages/features/git/lazygit/default.nix`:

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

`packages/features/git/lazygit/package.nix` is a thin wrapper: it takes
`upstream = pkgs.lazygit`, wraps it with `symlinkJoin` + `wrapProgram`,
bakes the config into `$out`, and sets
`passthru.upstreamVersion = upstream.version`. The wrapper still owns its
config even though the binary comes from nixpkgs.

Build outputs:

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
- `persist`: persistence entries interpreted by `systems/persistence`.

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

Toolchains live in `packages/toolchains/`:

```text
packages/toolchains/
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

`systems/packages` scans, validates, indexes, and resolves toolchains.
`packages/toolchains/_builder.nix` provides `mkToolchain` as a pure helper.
`systems/packages` exposes the tree-sitter home adapter.

There is no root `toolchains/` and no `systems/toolchains`.

### Runtime Package Records

Runtime tools live under `packages/runtime/<tool>/` with a record plus a
build, so the resolver gates binaries and closures:

```nix
# packages/runtime/vm/default.nix
{
  type = "runtime-tool";
  description = "VM lifecycle and MCP server";

  targets = [ "nixos" ];
  sides.home = { };

  provides.runtime-vm = { };
}
```

```text
packages/runtime/vm/
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

## Profiles

`profiles/*.nix` remain data, but each file is a graph node.

```nix
# profiles/desktop.nix
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
- `profiles/default.nix` logic moves to `systems/packages`.

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

`lib/store.nix` is replaced by derived facts from capabilities:

- `hasX11`
- `hasWayland`
- `isGraphical`
- `hasPortal`
- `hasNotifications`
- `hasClipboard`
- `hasAudio`
- `hasPaper`
- `hasVm`
- `hasLspmux`
- `hasRea`
- `defaultBrowser`
- `hasFirefox`

## Desktop Check

Desktop constraints live in the graph, not in feature assertions.

Provider examples:

```nix
# packages/features/display/x11/default.nix
provides = {
  display-server = { session = "x11"; };
};
```

```nix
# packages/features/wm/i3/default.nix
provides = {
  window-manager = { session = "x11"; };
};
```

```nix
# packages/features/display/ly/default.nix
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

`systems/validation` runs the desktop check for every host selecting a system
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
| runtime tools | `packages/runtime/*`, built by `systems/cli`, gated by runtime capabilities |
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
- Fatal evaluation errors render through `throwDiagnostics`.
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
- Existing `runtime/logger` seeds the shared Go logger under `systems/log`.
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

### Phase 1: Core, monads, logging, state contracts

- Keep `lib/core/*`.
- Delete stale `lib/schemas/*`.
- Move `lib/nixpkgs-config.nix` to the repository root.
- Add `lib/util/*` only for generic helpers.
- Implement `systems/monads` with ports, interpreters, and central tests.
- Add `systems/log` schema and diagnostics renderer.
- Add `systems/state` contracts.
- No production callers yet.
- Verify with `nix flake check --no-build --impure`.

### Phase 2: Target and context

- Add generated `hosts/<host>/target.nix` schema.
- Add explicit `angst host detect`.
- Add external capabilities to target observations.
- Add state schema versions, freshness, and atomic update rules.
- Add `systems/context` desired/observed/derived model.
- Add activation/deploy apps that choose backend from target kind.
- Missing target -> flake emits home config only plus `TGT001`.
- `angst switch` fails `TGT001` on missing target; no probe, no write, no
  fallback.
- Verify no flake evaluation reads the live machine.

### Phase 3: Packages, features, toolchains, profiles

- Move `domains/<cat>/<name>/` into `packages/features/<cat>/<name>/`.
- Move `default.nix` metadata into the package directory.
- Move `toolchains/*.nix` into `packages/toolchains/`.
- Move `lib/toolchain.nix` to `packages/toolchains/_builder.nix`.
- Add `packages/toolchains/_schema.nix`.
- Convert `profiles/*.nix` to graph profile nodes.
- Remove the static `profileMap`; discover profiles by filename.
- Move profile resolution into `systems/packages`.
- Add directory scanners for features, toolchains, runtime tools, and profiles.
- Add scanner tests: deterministic order, duplicate IDs, orphan dirs, invalid
  entries, skipped `_*` files.
- Add sides, targets, and conditional side schema.
- Add graph tests: closure, cycle, missing package, missing capability,
  ambiguous provider, conflicts, ordering, target support.
- Run resolver in diagnostics-only mode and compare selected sets.
- Enable auto-closure.
- Convert explicit assertions to `requires`/`conflicts`.
- Replace `lib/store.nix` with derived facts.
- Verify every host still evaluates.

### Phase 4: Desktop constraints and feature checks

- Add capability cardinality and compatibility checks.
- Add desktop validation.
- Move feature-specific checks beside features as `checks.nix`.
- Add fixture tests for one WM/server, duplicates, incompatibility, external
  providers, and generic-Linux target sides.
- Verify desktop profiles on NixOS and generic-Linux fixtures.

### Phase 5: Systems split and modules

- Move `lib/domains/*` and `lib/render.nix` into `systems/modules/internal`.
- Expose pairing, target-aware side selection, module generation, and build
  invocation (`package.nix` per selected package with host `theme` +
  `toolchains`).
- Move base home/NixOS modules to `systems/platform`.
- Move theme/Gtk/Qt modules to `systems/theme`.
- Move login shell to `systems/activation`.
- Move app secret and `modules/secrets.nix` to `systems/secrets`.
- Move `modules/nixos/persist.nix` to `systems/persistence`.
- Move `modules/nixos/persist-features.nix` data into feature package records.
- Move `modules/vm/*` and VM runtime code to `systems/vm`.
- Move project/db/vault/FTP runtime code to `systems/projects`.
- Move tree-sitter adapter to `systems/packages`.
- Delete root `modules/`.
- Compare built store-path config hashes before and after.

### Phase 6: Host and outputs

- Move `lib/discover.nix`, `lib/resolve.nix`, `lib/build/*` into
  `systems/host`.
- Move `lib/flake/*` into `systems/outputs`.
- Make `flake.nix` import only `systems/outputs`.
- Emit `nixosConfigurations` only for `target.kind = "nixos"`.
- Preserve all public output names.
- Preserve `.#lib.renderDomainOutputsFor`,
  `renderDomainOutputFor`, `renderProjectOutputs`, and `themeLint`.
- Keep shared catalog and toolchain caching for `x86_64-linux`.

### Phase 7: CLI, binaries, state

- Remove top-level `runtime/`.
- Move Go sources to `systems/cli` as one Go module.
- Split binaries by bounded context:
  `angst`, `angst-switch`, `angst-projects`, `angst-secrets`, `angst-vm`,
  `angst-shell`, `angst-analyze`, `angst-hm-switch`, `angst-log`.
- Build each binary as a separate derivation or separate Nix output. Never
  build all commands into one host closure.
- Preserve legacy names with thin wrappers:
  `vm`, `angst-shell`, `analyze`, `hm-switch`, `nixos-switch`.
- Move Nix activation glue to `systems/cli/wrappers/` or
  `systems/cli/internal/`.
- Move each Go tool build into its owning `packages/runtime/<tool>/`
  (`default.nix` record plus `package.nix` build plus `src/`); no separate
  recipe directory.
- Gate binaries through runtime capabilities.
- Move `domains/design/paper/package.nix` to
  `packages/features/design/paper/package.nix` and fold the wrapper flags
  into the same build.
- Move `lib/toolchain.nix` to `packages/toolchains/_builder.nix`.
- Move `lib/treesitter.nix` into the owning feature package build
  (grammar set baked in via the `toolchains` input).
- Wire adapters in context, secrets, VM, activation, projects, and log.
- Add `systems/state` with atomic writes, locks, schema versions, and
  `ANGST_STATE_DIR`.
- Implement `systems/activation`:
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

### Phase 8: Validation, enforcement, docs

Move `checks/*` into `systems/validation`.

Add `systems/validation/internal/architecture.nix`:

- no `systems/monads` outside `systems/`
- no `systems/<name>/internal` outside `systems/<name>/`
- no `systems/` imports from `lib/`, `packages/`, or `profiles/`
- no imports inside `packages/features/*/default.nix` or `profiles/`
- every `systems/<name>/` has `default.nix`
- no root `domains/`, `modules/`, `checks/`, `runtime/`, `toolchains/`, or
  `flake/`
- no single all-features runtime command binary
- runtime state files are not tracked in git, except explicit `target.nix`,
  `hardware.nix`, and `observations.nix`
- state files have schema versions and owners; no cross-system state paths

Add `systems/validation` checks for runtime closure, state, desktop, activation
(strict failures, phases, logs, history, redaction), and catalog discovery
(deterministic order, duplicate IDs, orphan directories, invalid entries).

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
NIXPKGS_ALLOW_UNFREE=1 nix build .#checks.x86_64-linux.build-ci --impure
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
- every profile ID exists in `packages/features/` or `profiles/`
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
- no feature module imports `systems/monads` or system internals
- context tests prove unknown is distinct from false
- log tests prove secret values are redacted

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
13. Splitting root `modules/` by bounded context creates duplication risk.
    Keep shared platform adapters in `systems/platform`; keep feature-specific
    modules in package directories.
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
19. Do not discover code systems, adapters, binaries, or validation modules.
    Keep code composition explicit; discovery is for data catalogs.

## Non-Goals

- No runtime probing during flake evaluation.
- No mutable context store.
- No central mutable state database used as flake input.
- No Nix derivation used as a database.
- No monad access outside `systems/`.
- No single all-features runtime binary.
- No runtime binary or wrapper for a disabled capability.
- No manual theme/toolchain/feature/profile catalog arrays.
- No runtime filesystem discovery for build catalogs.
- No implicit target detection or target write in `angst switch`.
- No hidden backend fallback when the target manifest or selected output is
  missing.
- No root `domains/`, `modules/`, `checks/`, `runtime/`, `toolchains/`, or
  `flake/` directory.
- No NixOS configuration output for `generic-linux` targets.
- No implicit deployment of a NixOS closure to a non-NixOS host.
