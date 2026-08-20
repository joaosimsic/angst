# Plan: Replace sops with vault/age (tarball store) in `angst projects` + `ftp`

## Model
- The **public repo holds two committed, encrypted tarballs**: `projects/personal.tar.age` and `projects/work.tar.age`. Each contains the whole `<scope>/<id>/{metadata.json,.env}` tree.
- The **decrypted** scope directories (`projects/personal/`, `projects/work/` — produced when you decrypt in-place for editing) and the per-host working store (`~/.secrets/projects/...`) are **gitignored** and never committed.
- The vault tar/untar preserves the full relative folder structure and files, so decrypting yields an editable tree.
- Manual edit flow:
  1. `angst vault decrypt projects/personal.tar.age --dir --scope personal` → `projects/personal/` (structure preserved, editable by hand).
  2. edit `projects/personal/<id>/metadata.json` / `.env`.
  3. `angst vault encrypt projects/personal --dir --scope personal` → overwrites `projects/personal.tar.age`, removes `projects/personal/`.
  4. `git add projects/personal.tar.age && git commit`.
- **ftp decrypt** → `shared.AgeDecrypt` (age); drop `sops`.
- **boot / `secrets.yaml` stays on sops** — it is consumed by **sops-nix** (NixOS), not angst. sops is therefore *not* fully removable.
- Scope isolation preserved: each tarball is encrypted with its scope's age recipient (the personal key is never a recipient for `work`).

## 1. Go changes

### `runtime/angst/internal/vault/`
- Export a new helper `DecryptTarball(keyfile, src, destDir string) error` that runs `shared.AgeDecrypt` followed by `untarDirectory` into `destDir`.
- Refactor `decryptDir` to call it (dest = `strings.TrimSuffix(src, ".tar.age")`) so CLI behavior is unchanged while allowing extraction into an arbitrary directory (needed for boot, which extracts into the working store, not the read-only nix store).

### `runtime/angst/internal/projects/`
- `helpers.go`: delete `sopsDecrypt`, `sopsDecryptToFile`, `encrypt`, and the sops/`fmt`/`filepath` usage tied to them. Keep `resolve`, `readMetadata`, `selected`, `keys`, `sha256hex`, `readTrimmed`, `copyChmod`, `envKeyDiff` (all used by `sync`).
- `cmd_other.go`: delete `cmdAdd`, `cmdStatus`, `cmdCapture`, `cmdEditEnv`, `cmdRm`, plus now-unused `randomID` and `missingKeys`.
- `cmd_import.go`: reimplement `cmdImport` — for each scope in `{personal, work}`, if `repoRoot()/<scope>.tar.age` exists, `vault.DecryptTarball(scope.AgeKeyfile(scope, scope.EnvOverride), tarball, storeRoot()/<scope>)`; warn and skip missing scopes. Drop `selected` filtering (whole-scope tarball; host selection still happens in `sync`). Keep `--all` accepted as a no-op.
- `cmd_sync.go`: no logic change (already reads the plaintext working store and clones).
- `projects.go`: `usage()` and the `Run` switch keep only `sync` and `import` (remove the other cases).
- `projects_test.go`: remove the sops round-trip test; add a vault-based test that builds the working store by hand, runs `vault encrypt --dir`, runs `import`, asserts a byte-exact working store, and verifies `sync` materializes `.env` (0600).

### `runtime/angst/internal/ftp/commands.go`
- `cmdDecrypt`: replace the `sops -d` exec with `shared.AgeDecrypt(workKey, src, tmpfile)`, `chmod 0600`, then atomic rename to `dst`. Remove the `bytes` import (`exec` is still needed for rclone/fusermount).

## 2. Nix wiring
- `runtime/projects-sync.nix`: drop `sops` from `runtimeInputs` (keep `git age openssh`). `ANGST_PROJECTS_REPO=${flakeSelf}/projects` stays (import reads tarballs from there).
- `runtime/ftp-secrets-home.nix`: drop `sops` from `runtimeInputs` (keep `age`).
- `domains/git/projects/home.nix`: keep `import; sync` (import now decrypts tarballs) — no structural change.
- `lib/build/mkNixos.nix` / `mkHome.nix`: no change (`projects` persistence and the `ANGST_PROJECTS_ONLY` specialArg are untouched).

## 3. Checks
- `checks/secrets.nix` `projectsCheck`: assert every `projects/*.tar.age` contains `BEGIN AGE ENCRYPTED FILE` (replace the `metadata.json`/`.env` sops checks).
- `checks/projects-pipeline.nix`: rewrite —
  - seed working store by hand (`personal` + `work`, with `metadata.json` + `.env`),
  - `angst vault encrypt <scope> --dir --scope <scope>`, move to `projects/<scope>.tar.age`,
  - wipe working store, run `angst projects import`, assert byte-exact round trip,
  - run `angst projects sync`, assert `.env` materialized (0600) with sidecar hash,
  - edit `.env` locally, run `sync` → assert non-zero rc and that the edited `.env` is not clobbered (drop the `status` STALE assertion since `status` is removed).
  - Remove `sops` / `jq` from `nativeBuildInputs` (keep `age git openssl coreutils gnugrep findutils openssh runtime.goAngst`).
- `checks/default.nix`: `check-projects-pipeline` already wired; `check-vault-pipeline` already added. No change.

## 4. Config / guardrails
- `.sops.yaml`: delete the `projects/personal/.*$` and `projects/work/.*$` creation rules (sops-specific). Keep the host `secrets.yaml` and `secrets/ftp` rules.
- `.gitignore`: add `projects/personal/` and `projects/work/` (the decrypted scope dirs) so in-place decrypt never commits plaintext. `*.tar.age` stays tracked (confirmed not ignored).
- `.gitleaks.toml`: the `angst-projects-plaintext-secret-value` rule already allowlists `BEGIN AGE ENCRYPTED FILE`, which covers `.tar.age`. Update the description only.

## 5. Docs
- `project.md`: update the plan to the tarball model — drop `export`/`import`(seed)/`status`/`capture`/`edit-env`/`add`/`rm`; document the manual vault decrypt → edit → encrypt → commit flow; scope-isolated tarballs.
- `openwiki/secrets.md` ("Project store (three layers)" section): rewrite to the tarball store + vault/age; note boot still uses sops for `secrets.yaml` (sops-nix).
- `runtime.md`: update references to `projects export/import/status`.

## 6. Verification
- `cd runtime/angst && go test ./...` (including `./internal/vault/...`).
- `nix build .#checks.x86_64-linux.check-projects-pipeline` and `check-vault-pipeline`.
- `nix flake check` (secrets / projects / ftp encryption checks).
- Manual: confirm `git status` does not stage plaintext after `angst vault decrypt projects/personal.tar.age --dir`; edit → re-encrypt → commit the `.tar.age`; on a host run `angst projects import && angst projects sync` and confirm clones appear.
