# sops → age migration

This repo is moving secret handling off **sops-nix** and onto the **age** store
that already backs SSH keys, FTP config, the project vault, and app secrets.
sops-nix was only ever used for per-host `secrets.yaml`; everything else was
already age. This document records the target design and the migration steps.
No code changes are made here — this is the spec.

## Why

- sops-nix powers exactly two things today: `masterPassword` (NixOS login hash)
  and `opencodeGoKey` (→ `~/.secrets/opencode-go-key`).
- SSH keys (`secrets/ssh/`), FTP (`secrets/ftp/`), the project vault
  (`projects/*.tar.age`), and app secrets (`secrets/apps/*.age`) are all
  **age**, decrypted by `angst` via `scope.AgeKeyfile`.
- The `~/.config/sops/age/keys.txt` path is just an age key location — it does
  not require the `sops` tool. Keeping the `sops` name after removing sops-nix
  is a misnomer, so the key location moves too.

## Target design

### Age key location

| Scope | Age key (new) | Encrypted secret in repo |
|---|---|---|
| personal | `~/.config/age/keys.txt` | `secrets/...` (per scope below) |
| work | `~/.config/age/work-keys.txt` | `secrets/...` |

- Env overrides renamed: `SOPS_AGE_KEY_FILE` → `ANGST_AGE_KEY_FILE`,
  `SOPS_WORK_AGE_KEY_FILE` → `ANGST_WORK_AGE_KEY_FILE`.
- Do **not** use `~/.config/angst/` for keys — the VM symlinks
  `~/.config/angst` → the host repo, so that path would resolve into the repo
  on the VM.

### Master password (per-host, age)

- Stored as `secrets/master/<host>.age`, encrypted with the host's scope age
  recipient. One file per host, preserving the current 1:1 host→password
  semantics.
- At boot, a **root** systemd oneshot (`angst-bootstrap-secrets`, before
  getty/display-manager) decrypts the age file with the age key and runs
  `angst set-password-hash`, which derives the sha-512 hash (`mkpasswd -m
  sha-512`) and applies it to the user + root via `usermod -p`.
- The host decl's `password` field remains the unseeded fallback (default
  `changeme`).

### App secrets

- `opencodeGoKey` moves out of `secrets.yaml` into the existing age app-secret
  path: `secrets/apps/<scope>/opencode-go-key.age`, provisioned by
  `angst provision-app-secret --slug opencode-go-key` (same mechanism as
  `cursor-api-key`). It lands at `~/.secrets/opencode-go-key`, which
  `domains/agents/opencode/config/opencode.jsonc` already reads.
- Add `"opencode-go-key"` to each host decl's `secrets = [...]` list
  (`hostSecrets = host.secrets`).

### SSH / FTP / projects

Unchanged — already age. Only their key *path* moves with the relocation
above.

## Migration steps (spec)

1. **Storage**
   - Add `secrets/master/<host>.age` per host.
   - Add `secrets/apps/<scope>/opencode-go-key.age`; add `"opencode-go-key"`
     to host `secrets` lists.
   - New `angst bootstrap-master-password --host HOST`: reads the password
     twice (no echo), encrypts with the scope recipient, writes
     `secrets/master/<host>.age`.

2. **Runtime decrypt at boot**
   - `angst set-password-hash`: replace `--sops-path` with `--age-path` +
     `--age-key`; decrypt via `shared.AgeDecrypt`, then hash + `usermod`.
   - `runtime/bootstrap-secrets.nix`: call the new invocation; keep
     `before = [getty, display-manager]`, `wantedBy = multi-user.target`.

3. **NixOS wiring**
   - `lib/build/mkNixos.nix`: gate `angst-bootstrap-secrets` on
     `builtins.pathExists (self + "/secrets/master/${host.hostname}.age")`;
     pass `agePath` + `ageKey = /home/<user>/.config/age/keys.txt`.
   - `modules/secrets.nix`: delete sops wiring (`homeCore`/`systemCore`/
     `mkCore`/`syncActivation`/sops import); `persistDirs` `.config/sops` →
     `.config/age`; drop `opencodeGoKey` from `homeSecretDefs`.
   - `modules/home/secrets-activation.nix` & `app-secrets.nix`: remove the
     `sops-nix.service` ordering dependency.

4. **Relocate age keys → `~/.config/age/`**
   - `scope.AgeKeyfile` → `~/.config/age/keys.txt` / `work-keys.txt`;
     env vars → `ANGST_*`.
   - `provision_ssh_key.go`: use `scope.AgeKeyfile` instead of hardcoded paths.
   - `vm.go` `sopsDir` → `~/.config/age`.
   - `tools/vm/crates/vm-core/src/shared.rs` `AGE_KEY_SOURCES` →
     `~/.config/age/...`.
   - `shared/age.go` `AgeEncrypt`: set `ANGST_AGE_KEY_FILE`.
   - `checks/vault-pipeline.nix`, `checks/projects-pipeline.nix`: mkdir/keygen/
     export under `~/.config/age` + `ANGST_*`.
   - Tests: `scope_test.go`, `projects_test.go`, `vault_test.go`.

5. **CI / checks / gitleaks**
   - `checks/secrets.nix` `check-secrets-encrypted`: repurpose to assert every
     `secrets/master/*.age` carries an `age-encryption.org/v1` envelope
     (mirror `check-ssh-keys`/`check-ftp-encrypted`); drop the `secrets.yaml`
     scan.
   - `.gitleaks.toml`: broaden `angst-plaintext-secret-value` to also guard
     `secrets/master/`; drop sops-specific notes.
   - Delete `.sops.yaml` (only consumed by sops; its `secrets/ftp/.*` age rule
     is vestigial).

6. **flake.nix**
   - Remove the `sops-nix` input and all `inputs.sops-nix.*` references.

7. **Docs**
   - Update `openwiki/secrets.md`, `README.md`, `architecture.md`, `tools.md`,
     `operations.md`, `quickstart.md`, `work-host.md` to reflect age-based
     master password + app secrets and `~/.config/age/`. Fix the
     `vm-profile.nix` "for sops decryption" string.

## Unaffected

- Home-only hosts (mint, work/home) never had `masterPassword` (type ≠ nixos);
  they only used `opencodeGoKey`, now served by the age app-secret path.
- SSH keys, FTP, projects, and VM key injection stay age-based — only the key
  *path* moves.
