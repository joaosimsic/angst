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
- **Defer** `apps/analyze*` (Python), `apps/check`/`apps/lint-*`/`apps/ssh-deploy`
  (flake-app wrappers), and `devshell-hook.nix` (pure shellHook, not a command)
  — unchanged for now.

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
    system/   login-shell, ssh-add-keys, provision-ssh-key
    ftp/      decrypt (ftp-secrets-home), transform (JSON→INI), mount|unmount
    vm/       age-key, ephemeral-ssh, home-manager-upgrade, nixos-switch, home-switch
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

## Bash → Go mapping (behavior-preserving)

| Bash (today) | Go subcommand | Notes |
|---|---|---|
| `angst-cli.nix` internals | `render`, `watch`, `bootstrap-secrets`, `projects`, `ssh-key` | watch re-execs `os.Executable render ...`; preserve `--repo/--host/--theme/--reload`, `NIX_DEFAULT_TARGET_HOST`, theme default from `config_val theme` |
| `angst-projects.sh` (concatenated into CLI + sync) | `projects *` | single code path; preserve env contract (`ANGST_PROJECTS_{STORE,REPO,ROOT,ONLY}`, `SOPS_{,WORK_}_AGE_KEY_FILE`), exit codes (stale → 1), `--all` import/export, byte-exact sops binary round-trip |
| `bootstrap-secrets.nix` (systemd service) | `set-password-hash` (baked args: `--username`, `--sops-path`) | keeps `mkpasswd -m sha-512` + `usermod` shell-outs |
| `projects-sync.nix` | wrapper: `exec angst projects "$@"` + baked `ANGST_PROJECTS_{REPO,ONLY,STORE}` env |
| `ftp-secrets-home.nix` | `ftp decrypt` (baked home + configs) | warn+exit 0 on missing work key |
| `ftp-mount.nix` + `ftp-mount-lib.sh` | `ftp mount|unmount`, `ftp transform --conf --ini` | transform prints `remote=`/`path=` on stdout for the pipeline check |
| `login-shell.nix` | `login-shell` | honor `$VERBOSE_ECHO`/`$DRY_RUN_CMD` passthrough from home activation |
| `ssh-add-keys.nix` | `ssh-add-keys` (baked keys) | |
| `ssh-key-provision.nix` | `provision-ssh-key` (baked user/home/secrets-dir) | |
| `vm/*.nix` (5) | `vm age-key|ephemeral-ssh|home-manager-upgrade|nixos-switch|home-switch` | |

## Dedup wins (the point of the rewrite)

| Duplication today | After |
|---|---|
| Scope→age-keyfile mapping in 4 files | one `internal/scope` |
| Sops encrypt/decrypt + recipient boilerplate in 3 files | shared helpers |
| `angst-projects.sh` **concatenated** into CLI *and* projects-sync | one `angst projects` code path; sync service just `exec angst projects "$@"` |
| repo-root / host-config lookup in 3 places | `internal/paths` |
| jq/sha256sum/diff/openssl ad-hoc shell plumbing | stdlib, typed, unit-testable |

## Nix refactor (`runtime/*.nix`)

- `default.nix` builds `goAngst = pkgs.buildGoModule { src = ./angst; vendorHash = null; }`
  (stdlib-only → `vendorHash = null`; nixpkgs refuses a non-null hash for an
  empty vendor dir, so no constant is needed) and exports it.
- Each `runtime/*.nix` becomes a one-liner body, e.g.:
  - `angst-cli.nix` → `exec ${goAngst}/bin/angst "$@"` with `runtimeInputs =
    [nix sops age git openssh watchexec coreutils findutils]` (jq/openssl/diffutils
    dropped).
  - `projects-sync.nix` → `exec …/angst projects "$@"` + the same `ANGST_PROJECTS_*`
    env as today.
  - `ftp-secrets-home.nix`, `vm/age-key.nix`, etc. → `exec …/angst <sub> <baked args>`.
- Script names are preserved (`angst-projects-sync`, `angst-ftp-mount`,
  `angst-ftp-secrets-home`, `angst-vm-*`, `ssh-add-keys`, `angst-set-login-shell`,
  `angst-provision-ssh-key`, `angst-bootstrap-secrets`) so all `.bin` consumers
  are untouched.
- `.bin` shape preserved everywhere → **zero changes** in `mkNixos.nix`,
  `mkHome.nix`, `modules/vm/vm-profile.nix`, `domains/*`, `lib/flake/*`.
- Delete `angst-lib.sh`, `angst-projects.sh`, `ftp-mount-lib.sh` (then only
  `domains/editor/nvim/config/tests/run.sh` remains for the shfmt CI job).

## Checks + CI + docs

- `checks/projects-pipeline.nix`: replace `cat runtime/angst*.sh` + sourcing with
  driving `${runtime.goAngst}/bin/angst projects export/import/sync/status` against the
  same synthetic store/env (keeps the "test real code" guarantee; the lean raw
  `goAngst` binary + existing `nativeBuildInputs` avoid pulling the `nix`
  closure into the check). `runtime` must be threaded into this check (currently
  only `pkgs`).
- `checks/ftp-pipeline.nix`: keep using `${runtime.ftpSecretsHome}` (still a `.bin`),
  swap the `ftp-mount-lib.sh` sourcing for `${runtime.goAngst}/bin/angst ftp transform --conf … --ini …`
  and read its `remote=`/`path=` stdout.
- `.github/workflows/checks.yml`: add `runtime/**` to the `tools` paths-filter and a
  `go` job (`gofmt -l . && go vet ./... && go test ./...` via `nix develop .#dev`).
- **`lib/flake/devshell.nix`**: add `go` + `gofumpt` to `fullDevPackages` (the dev
  shell does *not* ship Go today).
- `justfile`: add `go-fmt` / `go-test` recipes.
- Update `README.md`/`openwiki/tools.md` runtime references (generated OpenWiki
  pages left to the cron job).

## Implementation order

1. Go scaffold: `go.mod`, `main.go` dispatcher, `internal/paths`, `internal/scope`
   (+ unit tests).
2. `internal/projects` (biggest, and the pipeline check validates it) and
   `internal/ftp` — both have flake checks that prove byte-exact behavior.
3. `render`/`watch`, `sshkey`, `boot` (interactive + service), `system`, `vm`.
4. Nix wrappers + deletions; rewrite the two pipeline checks.
5. Dev shell, CI, justfile, docs.

## Verification

- `gofmt -l .` + `go test ./...` (unit tests for projects/env-hash/stale logic,
  scope resolution, ftp transform, repo-root resolution).
- `nix build .#angst` and `nix flake check` (incl. rewritten pipelines).
- Spot-build `.#nixosConfigurations.vm`, `.#homeConfigurations.joao` and the mint
  (home-only) config — proves the `.bin` contract intact.
- Manual: `angst render`, `angst watch`, `angst projects add/export/import/status`,
  `angst ssh-key verify`, stale-env no-clobber.

## Risk notes

- `buildGoModule` with a stdlib-only module needs `vendorHash = null` (nixpkgs
  errors on a non-null hash for an empty vendor dir — no `lib.fakeHash` dance).
- The systemd service scripts run as root/early-boot — Go binary's PATH comes from
  the Nix wrapper's `runtimeInputs`, same guarantee as today; `ephemeral-ssh`
  additionally bakes absolute tool paths as CLI args (early-boot PATH is minimal).
- Naming of new subcommands (`set-password-hash`, ...) is flexible; the mapping to
  existing script names is preserved in the wrappers, so nothing external cares.
- The two pipeline checks enforce byte-exact sops round-trip and `stale → exit 1`
  — `projects` and `ftp` were ported first so regressions surfaced immediately.

## Implementation deltas vs this plan

- **Pipeline checks drive `runtime.goAngst`** (the raw `buildGoModule` binary),
  not `runtime.angstCli.bin` — the wrapper pulls the `nix` closure into the check
  for no reason; the checks' `nativeBuildInputs` already provide sops/age/git/ssh.
- **`angst ssh-key` keyfile policy**: `ssh-key`/`provision-ssh-key` use the fixed
  home paths (personal → `~/.config/sops/age/keys.txt`, work → `work-keys.txt`);
  projects/ftp honor `SOPS_{,WORK_}AGE_KEY_FILE`.
- **`bootstrap-secrets` decl edit**: the old `sed "/^\s*};/i"` inserted before
  *every* `};` line (corrupting decls with multiple nested attrsets) and no-opped
  on decls closing with `}`. The Go port inserts before the final top-level
  closing brace instead — a deliberate bug fix.
- **Redacted env diff**: replaced gnu `diff`'s `XcY`/`---` markers with plain
  `  store: KEY` / `  local: KEY` lines (still key-name only).
- **ephemeral-ssh** bakes `--mountpoint-bin/--mount-bin/--rm-bin/--cp-bin/--mkdir-bin`
  absolute store paths as args (early-boot PATH independence preserved).
