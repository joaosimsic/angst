# runtime.md — Runtime Tooling as a Nix Function Library

Status: **plan — not implemented**

## Problem

Bash appears in the repo in three bad shapes:

1. **Inline script strings** scattered across modules (`writeShellApplication`/`writeShellScript`
   text in `mkNixos.nix`, `login-shell.nix`, `vm-profile.nix`, `ssh-agent.nix`, `apps.nix`,
   `devshell.nix`) — written by hand at every call site, duplicated, no single owner.
2. **Duplicated assembly** of the `angst` CLI from `scripts/*.sh` — the same
   `builtins.concatStringsSep (map builtins.readFile [...])` concat exists in three places
   (`lib/flake/context.nix:61`, `modules/vm/vm-profile.nix:27`,
   `domains/git/projects/home.nix:24`).
3. **Bash embedded in Nix strings** with no editor syntax highlighting at edit time and no
   reuse — the thing that originally motivated this.

## Goal

Make every runtime script a **Nix function you call from the main system**. The reusable unit
is the function, not a loose `.sh` file. The function owns:

- the script's parameters (caller-supplied values: `keys`, `username`, `repoPath`, flake refs…)
- its `runtimeInputs` (tools resolved via PATH, injected by `writeShellApplication`)
- its `excludeShellChecks` / shellcheck policy
- the bash body (inline, direct `${...}` interpolation — no placeholder machinery)

## Key decisions (agreed)

- Scripts live **inline in `.nix` functions** — no `.sh` siblings, no `@placeholder@`
  substitution, no injection bridge. `writeShellApplication` still runs shellcheck at build
  time, so validation survives even with inline bash.
- The library is **built once and injected via `specialArgs`** (same mechanism as
  `themesLib`/`secrets`), so any module calls `runtime.xxx { ... }`.
- Every factory returns a derivation that also exposes **`.bin`** — the absolute store path to
  its `bin/<name>` entry (`drv // { bin = "${drv}/bin/${name}"; }`, plus `meta.mainProgram`).
  Call sites use `runtime.xxx { ... }.bin` for `ExecStart`/activation strings and the raw
  derivation for `home.packages`. No `/bin/<name>` knowledge leaks out of `runtime/`.
- **Build-time bash stays put.** `pkgs.runCommand` build commands (`checks/*.nix`,
  `lib/treesitter.nix`) execute during `nix build` — they are validation, not runtime tooling,
  and do NOT move into the runtime library.

## Mental model

- **Runtime bash** — `writeShellScript` / `writeShellApplication` / `writeText`-sourced hooks.
  Executes when invoked, never during `nix build`. → belongs in `runtime/`.
- **Build-time bash** — `runCommand` build commands. Executes during `nix build`. → stays in
  `checks/`, `lib/treesitter.nix`.

## Store behavior: only what's built gets baked

Nix builds only the **dependency closure of the target you request**, and flake output attrsets
are lazy. Consequences:

- Building one host (`nix build .#homeConfigurations.joao.activationPackage`,
  `nixos-rebuild switch --flake .#nixos`) forces **only that host's** config. Other hosts'
  script variations are never evaluated, never `.drv`-written, never copied to the store. There
  is no `runner` variation baked when building the `joao` machine.
- One machine per host ⇒ each machine's store holds exactly the one variation of each script it
  needs. Identical invocations across hosts share one content-addressed store path.
- **Exception: `nix flake check`** forces everything reachable from `checks`. The checks
  reference the representative host's *test* configs (`checks/default.nix:79-82`:
  `home-theme-override-test`, `login-shell-valid` with `shellOverride = "sh"`,
  `login-shell-invalid`), so check bakes those test variants. That's expected and harmless —
  it does not touch other hosts' real scripts.

### Baked variation across the current hosts (`hosts/*/default.nix`)

| Value baked | Distinct values | Notes |
|---|---|---|
| `username` | 2 | `joao` (nixos/mint/vm) vs `runner` (ci) |
| `homeDirectory` | 2 | `/home/joao` vs `/home/runner` |
| `repoPath` | 2 | `proj/angst` (nixos/ci) vs `.config/angst` (vm); mint uses none |
| `hostname` | 4 | only feeds `ssh-deploy` default target + a `-C` comment |
| `ssh keys` | 1 | all hosts `["~/.ssh/id_ed25519"]` |
| `shell` | 1 (empty) | login-shell disabled on all hosts (`shell = ""`); only test configs use `"sh"` |
| `projects` | 2 | `[]` vs `["7391b51c36a7d266"]` (vm) |

Worst case per script: ~2–4 store copies across the whole fleet, KB-scale, deduped for
identical combos. Baked variation is a non-issue.

## Target layout

```
runtime/
  default.nix            # { pkgs, lib, self, inputs } -> mkScript wrapper + attrset of factories
  login-shell.nix        # { shell, homeDirectory, username } -> writeShellApplication
  ssh-add-keys.nix       # { keys } -> writeShellApplication
  bootstrap-secrets.nix  # { username, hostname, sopsPath } -> writeShellApplication
  projects-sync.nix      # { repoPath, projects, flakeSelf } -> writeShellApplication
  devshell-hook.nix      # { vm env vars } -> writeText (shellHook)
  angst-cli.nix          # -> the `angst` tool, single assembly
  apps/
    render.nix           # wraps angst render "$@"
    watch.nix            # wraps angst watch "$@"
    check.nix            # nix flake check --print-build-logs
    lint-themes.nix      # nix eval self#lib.themeLint --raw
    lint-desktop.nix     # nix build self#checks.<sys>.lint-desktop ...
    lint-shell.nix       # nix build self#checks.<sys>.lint-shell ...
    analyze.nix          # python3 -m scripts.analyze_flake "$@"
    analyze-to-file.nix  # analyze --output analysis.md
    ssh-deploy.nix       # build + activate home-manager on target
  vm/
    home-manager-upgrade.nix  # { username } -> writeShellApplication
    ephemeral-ssh.nix         # -> writeShellApplication
    authorized-keys.nix       # { username, homeDirectory } -> writeShellApplication
    age-key.nix               # { username, homeDirectory } -> writeShellApplication
```

## Interface shape

`runtime/default.nix` exposes a `mkScript` wrapper that every factory goes through. It wraps
`writeShellApplication` and attaches the `.bin` attribute (plus `meta.mainProgram`) so callers
never hardcode a path:

```nix
# runtime/default.nix (excerpt)
{ pkgs, lib, self, inputs }:
let
  mkScript = { name, text, runtimeInputs ? [ ], excludeShellChecks ? [ ], meta ? { } }:
    let
      drv = pkgs.writeShellApplication {
        inherit name text runtimeInputs excludeShellChecks;
        meta = meta // { mainProgram = name; };
      };
    in
    drv // { bin = "${drv}/bin/${name}"; };
in {
  loginShell = { shell, homeDirectory, username }:
    mkScript {
      name = "angst-set-login-shell";
      runtimeInputs = with pkgs; [ coreutils gnugrep bash ];
      text = '' ... '';   # direct ${...} interpolation of shell/homeDirectory/username
    };
  # ... every factory goes through mkScript
}
```

Call sites consume it without any path knowledge:

```nix
home.activation.setLoginShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  ${runtime.loginShell {
    shell = cfg.shell;
    homeDirectory = config.home.homeDirectory;
    username = config.home.username;
  }}.bin
'';
```

```nix
serviceConfig.ExecStart = runtime.bootstrapSecrets {
  username = host.username;
  hostname = host.hostname;
  sopsPath = config.sops.secrets.masterPassword.path;
}.bin;
```

```nix
home.packages = [ runtime.projectsSync { repoPath = repoPath; projects = projects; } ];  # derivation directly
```

## Derivation ownership: derive where you use

Parameters are declared **once per owning module**. A `let` binding is only needed when the
same instance is consumed in 2+ places; single-use sites inline the factory call directly.

| Factory | Consumers in its module | Need `let`? |
|---|---|---|
| `loginShell` | 1 (activation) | No — inline `.bin` |
| `sshAddKeys` | 1 (ExecStart) | No — inline `.bin` |
| `vm.homeManagerUpgrade` / `.ephemeralSsh` / `.authorizedKeys` / `.ageKey` | 1 each (ExecStart) | No — inline `.bin` |
| `bootstrapSecrets` | 1 (ExecStart) | No — inline `.bin` |
| `projectsSync` | 3 (packages + activation + ExecStart) | **Yes** — one `let` |
| `angstCli` | many, but **no params** | No — bare `runtime.angstCli` |

Single-use (inline, no `let`):

```nix
home.activation.setLoginShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  ${runtime.loginShell { shell = cfg.shell; homeDirectory = config.home.homeDirectory; username = config.home.username; }}.bin
'';
```

Multi-consumer (one `let`, params said once, `.bin` reuses the same instance):

```nix
{ config, lib, pkgs, runtime, repoPath, projects, ... }:
let
  sync = runtime.projectsSync { inherit repoPath projects; };
in {
  home.packages = [ sync ];                                   # drv mode (install)
  home.activation.angstProjectsSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${sync.bin} sync || true                                  # path mode, no re-derivation
  '';
  systemd.user.services.angst-projects-sync.Service.ExecStart = "${sync.bin} sync";
}
```

### Cross-module instances

Every parameterized script is derived **and** consumed inside its owning module. The only
cross-module script is `angstCli`, which takes no params — its single instance (and `.bin`)
lives in the runtime library itself, so `runtime.angstCli.bin` works from any module without
re-deriving. If a param'd script ever needs cross-module use, derive it once at the
host/context level and thread the instance via `specialArgs` (same mechanism as `themesLib`,
`secrets`, and `runtime` itself) — share the reference, `.bin` comes along for free.

## Wiring

1. `lib/flake/context.nix` builds the library once and returns it:
   `runtime = import ../runtime.nix { inherit pkgs lib self inputs; }`.
2. `lib/build/mkHome.nix` (`extraSpecialArgs`, ~line 47) adds `runtime`.
3. `lib/build/mkNixos.nix` adds `runtime` to BOTH the nixos `specialArgs` (~line 52) and the
   home-manager `extraSpecialArgs` (~line 167).
4. Modules destructure `runtime` in their function args and call factories.

## Migration table

| Current | → Call | Notes |
|---|---|---|
| `lib/flake/context.nix:47` (angstTool assembly) | `runtime.angstCli` | single source |
| `modules/vm/vm-profile.nix:13` (angstCli assembly) | `runtime.angstCli` | removes duplication |
| `domains/git/projects/home.nix:12` (projectsSync) | `runtime.projectsSync { repoPath; projects; flakeSelf; }` | env glue becomes args |
| `lib/build/mkNixos.nix:99` (bootstrapSecrets) | `runtime.bootstrapSecrets { username; hostname; sopsPath; }` | sopsPath from `config.sops.secrets.masterPassword.path` |
| `modules/home/login-shell.nix:21` (loginShell) | `runtime.loginShell { shell; homeDirectory; username; }` | args instead of `$1/$2/$3` |
| `domains/remote/ssh/ssh-agent.nix:19` (sshAddScript) | `runtime.sshAddKeys { keys; }` | resolved key paths as args |
| `modules/vm/vm-profile.nix:39,76,93,111` | `runtime.vm.homeManagerUpgrade`, `.ephemeralSsh`, `.authorizedKeys`, `.ageKey` | username/homeDir as args |
| `lib/flake/apps.nix:26-33` | `runtime.apps.*` | `exec ${runtime.angstCli.bin} render "$@"` etc. — `/bin/angst` knowledge dies inside the factories |
| `lib/flake/devshell.nix:22` (shellDevHook) | `runtime.devshellHook` | still `writeText`, sourced as today |
| `modules/home/secrets-activation.nix` | **stays generated** | already the model — a Nix function emitting per-secret bash |
| `checks/*.nix`, `lib/treesitter.nix` | **untouched** | build-time bash |

## Cleanup

- `scripts/angst-*.sh` fold into `runtime/angst-cli.nix`:
  - Small parts (`angst.sh`, `angst-render.sh`, `angst-watch.sh`, `angst-lib.sh`,
    `angst-bootstrap-secrets.sh`) fold inline.
  - `angst-projects.sh` (~16 KB, pure bash, zero interpolation) stays as a `readFile`'d
    sibling to avoid re-indenting churn — the one hybrid exception.
- `scripts/analyze_flake/` (python) stays where it is.
- `githooks/`, `tools/`, `checks/` untouched.
- Delete the `scripts/angst-*.sh` files after folding.

## Verification

- `nix flake check` — runs build-time checks AND shellcheck on every new
  `writeShellApplication` body at build time.
- `statix` / `deadnix` via the existing `checks.lint-nix` check.
- grep for stale `scripts/` references (`lib/flake/context.nix`, `modules/vm/vm-profile.nix`,
  `domains/git/projects/home.nix`).
- grep that no call site hardcodes a `/bin/<name>` path — all `ExecStart`/activation usages go
  through `runtime.xxx { ... }.bin`.
- Confirm `builtins.toString self` stringifies identically to today's `${self}#...` for the
  `apps` flake-ref wrappers.
- Confirm `writeShellApplication` build-time shellcheck does not flag existing code that
  previously relied on `excludeShellChecks` or quiet warnings.

## Non-goals

- Build-time bash in `checks/*` and `lib/treesitter.nix` stays inline in `runCommand` —
  it is validation, not runtime tooling.
- No `.sh` extraction, no placeholder/substitution machinery.
