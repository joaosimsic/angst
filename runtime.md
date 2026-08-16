# runtime/ rewrite — bash → Go

Plan for replacing the bash scripts in `runtime/` (currently bash glued onto Nix
via `mkScript`/`writeShellApplication`, assembled at eval time) with a **single
Go binary**.

## Goal

Port every runtime command to one Go binary while keeping the **exact same Nix
contract** (`runtime.<piece>.bin`, parameterized at eval time), so every
consumer — systemd `ExecStart`, home activation entries, `home.packages`, flake
apps, VM services — keeps working unchanged. Thin Nix wrappers only bake args +
inject PATH; the Go code lives in one place.

## Scope decisions

- Port **everything** in `runtime/` to Go.
- Keep shelling out to external tools (`nix`, `sops`, `age`, `git`,
  `ssh-keygen`, `watchexec`, `rclone`, `fusermount`, `mkpasswd`/`usermod`,
  `chsh`).
- Use **Go stdlib only** (no external Go deps): `encoding/json` replaces `jq`,
  `crypto/sha256` replaces `sha256sum`/`diffutils`, `crypto/rand` replaces
  `openssl rand`, `text/tabwriter` for the status table.
- Build via `pkgs.buildGoModule` inside `runtime/default.nix` (no new flake
  input).
- **Defer** `apps/analyze*` (Python) and `devshell-hook.nix` (pure shellHook,
  not a command) — unchanged for now.

## Go module layout (`runtime/angst/`)

```
runtime/angst/
  go.mod, main.go            # subcommand dispatcher
  internal/
    paths/    repo-root resolution (ANGST_REPO_ROOT → git → fallback → pwd),
              host-dir lookup, config_val (nix eval callbacks)
    scope/    personal/work keyfile + recipient (age-keygen -y) + ssh keyfile — ONE source
    projects/ add|sync|status|capture|edit-env|import|export|rm, env sidecar
              hashing, stale detection, redacted key-only diff, clone-if-missing
    render/   nix eval batch → JSON decode → write files → .gitignore sync → i3 reload
    sshkey/   generate | verify (age encrypt/decrypt + pub cross-check)
    boot/     interactive bootstrap-secrets (CLI)  +  set-password-hash (systemd service)
    system/   login-shell, ssh-add-keys, provision-ssh-key, ftp {decrypt,mount,transform}, vm subcommands
```

Subcommand surface (all from **one binary**, `angst`):

- `render`
- `watch`
- `bootstrap-secrets`
- `projects <add|sync|status|capture|edit-env|import|export|rm>`
- `ssh-key <generate|verify>`
- `login-shell`
- `ssh-add-keys`
- `provision-ssh-key`
- `set-password-hash`
- `ftp <decrypt|mount|unmount|transform>`
- `vm <home-manager-upgrade|ephemeral-ssh|age-key|nixos-switch|home-switch>`

## Dedup wins (the point of the rewrite)

| Duplication today | After |
|---|---|
| Scope→age-keyfile mapping in 4 files | one `internal/scope` |
| Sops encrypt/decrypt + recipient boilerplate in 3 files | shared helpers |
| `angst-projects.sh` **concatenated** into CLI *and* projects-sync | one `angst projects` code path; sync service just `exec angst projects "$@"` |
| repo-root / host-config lookup in 3 places | `internal/paths` |
| jq/sha256sum/diff/openssl ad-hoc shell plumbing | stdlib, typed, unit-testable |

## Nix refactor (`runtime/*.nix`)

- `default.nix` builds `goAngst = pkgs.buildGoModule { src = ./angst; vendorHash = …; }`
  (stdlib-only → tiny go.sum) and exports it.
- Each `runtime/*.nix` becomes a one-liner body, e.g.:
  - `angst-cli.nix` → `exec ${goAngst}/bin/angst "$@"` with `runtimeInputs =
    [nix sops age git openssh watchexec coreutils findutils]` (jq/openssl/diffutils
    dropped).
  - `projects-sync.nix` → `exec …/angst projects "$@"` + the same `ANGST_PROJECTS_*`
    env as today.
  - `ftp-secrets-home.nix`, `vm/age-key.nix`, etc. → `exec …/angst <sub> <baked args>`.
- `.bin` shape preserved everywhere → **zero changes** in `mkNixos.nix`,
  `mkHome.nix`, `modules/vm/vm-profile.nix`, `domains/*`, `lib/flake/*`.
- Delete `angst-lib.sh`, `angst-projects.sh`, `ftp-mount-lib.sh`.

## Checks + CI + docs

- `checks/projects-pipeline.nix`: replace `cat runtime/angst*.sh` + sourcing with
  driving `${runtime.angstCli.bin} projects export/import/sync/status` against the
  same synthetic store/env (keeps the "test real code" guarantee).
- `checks/ftp-pipeline.nix`: keep using `${runtime.ftpSecretsHome}` (still a `.bin`),
  swap the `ftp-mount-lib.sh` sourcing for `angst ftp transform --conf … --ini …`.
- `.github/workflows/checks.yml`: add `runtime/**` to the `tools` paths-filter and a
  `go-fmt`/`go-tests` job (`gofmt -l . && go test ./...` via `nix develop .#dev`,
  which already ships Go).
- `justfile`: add `go-fmt` / `go-test` recipes.
- Update `README.md`/`openwiki/tools.md` runtime references (generated OpenWiki
  pages left to the cron job).

## Verification

- `nix build .#angst` and `nix flake check` (incl. rewritten pipelines).
- `go test ./...` for projects/env-hash/stale logic, scope resolution, ftp transform.
- Spot-build a home config + VM config that exercise the `.bin` consumers.

## Risk notes

- `buildGoModule` needs `vendorHash`; stdlib-only keeps it a one-time
  `lib.fakeHash` → real hash swap.
- The systemd service scripts run as root/early-boot — Go binary's PATH comes from
  the Nix wrapper's `runtimeInputs`, same guarantee as today.
- Naming of new subcommands (`set-password-hash`, ...) is flexible; the mapping to
  existing script names is preserved in the wrappers, so nothing external cares.