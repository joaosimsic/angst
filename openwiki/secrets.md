# Secrets

angst uses **sops-nix + age** to keep secrets out of the repository while making them available on every machine (including the disposable VM). Secrets are optional at build time and decrypted at runtime; if a machine can't decrypt, the system still builds and boots with defaults.

## Model

- **Per-host secret files**: `hosts/<domain>/<hostname>/secrets.yaml` (or `hosts/<hostname>/secrets.yaml`). Only `hosts/vm/secrets.yaml` and `hosts/personal/mint/secrets.yaml` exist today; `hosts/personal/nixos/` has none.
- **Encryption**: sops, age recipients configured in `.sops.yaml` (rules per `hosts/<domain>/.*/secrets.yaml` and `hosts/vm/secrets.yaml`). Files are checked at eval/CI time to contain a `sops:` block and `ENC[AES256_GCM` ciphertext.
- **Keys**: age key at `~/.config/sops/age/keys.txt`, or `SOPS_AGE_KEY` / `SOPS_AGE_KEY_FILE` env vars (used in CI/tooling). Keys are **not** committed (`.gitignore` ignores `*.agekey`).
- **Secret values** (declared in `modules/secrets.nix`):
  - `opencodeGoKey` → `~/.secrets/opencode-go-key` (mode 0600) — consumed by the opencode domain via `{file:~/.secrets/opencode-go-key}` (see `domains/agents/opencode/config/opencode.jsonc`).
  - `masterPassword` (NixOS hosts only) — the machine's master password: source of the login hash and the SSH key passphrase.

## How it works (`modules/secrets.nix`)

`secrets.nix` is evaluated per host with `{ inputs, self, host, lib }`:

1. Locates the host's `secrets.yaml` → `hasSecrets`.
2. Detects an age key (`SOPS_AGE_KEY`/`SOPS_AGE_KEY_FILE` env or `~/.config/sops/age/keys.txt`) → `hasAgeKey`.
3. `canDecrypt = hasSecrets && hasAgeKey`. Everything below is gated with `mkIf canDecrypt`, so builds never fail on missing keys.
4. `mkCore secretDefs` wires the sops-nix module: `sops.age.keyFile`, `sops.defaultSopsFile = secrets.yaml`, `sops.secrets.<name> = {}`. Emitted as `homeCore` (home secrets + masterPassword) and `systemCore` (masterPassword only).
5. `syncActivation` adds a home activation entry `secrets-ready` (after `sops-nix`) that starts the user-level `sops-nix.service` — resilient when user systemd isn't fully running at activation time (fix `5ddca8d`).
6. `homeModules` = sops home module + `syncActivation` + `homeCore` + `modules/home/secrets-activation.nix`.

### `modules/home/secrets-activation.nix` — the "secret daemon"

For each declared secret present in `config.sops.secrets`, it copies the decrypted value to its `target` under `~/.secrets` with the declared mode:

- a home activation `secrets-to-home` (after `secrets-ready`), **and**
- a `systemd.user` service `secrets-to-home` (after `sops-nix.service`) so secrets land even outside the activation path (commit `efb4c66 feat: secret daemon`; refactored in `ea81277`).

The opencode API key therefore ends up at `~/.secrets/opencode-go-key` at login, not only at activation time.

## Master password bootstrap

The master password drives two bootstrap paths, both reading `config.sops.secrets.masterPassword.path`:

- **System** (`lib/build/mkNixos.nix`): `angst-bootstrap-secrets` oneshot service (before getty/display-manager) runs `mkpasswd -m sha-512` on the decrypted password and applies the hash to user + root via `usermod -p`, then generates `~/.ssh/id_ed25519` with the master password as passphrase (repairing the passphrase if the key exists with a different one). This is the single owner of the SSH-key bootstrap; the home-manager side (moved into `domains/remote/ssh/`) configures the client + agent only.

This replaces the old approach of baking a password hash into the host decl; the hash in the decl is only the unseeded fallback (`changeme` default in `lib/resolve.nix`).

## VM secret forwarding

The disposable VM decrypts the same secrets as the host **without baking keys into the image**:

- The host's age key and SSH public keys are copied into the VM's shared dir (`/tmp/shared` on the guest) by the `tools/vm` runner scripts (`vm-run`/`res`), which gather `ssh-add -L` + `~/.ssh/*.pub` and the age key.
- `modules/vm/vm-profile.nix` installs them: `vm-age-key` → `~/.config/sops/age/keys.txt`, `vm-authorized-keys` → `~/.ssh/authorized_keys`.
- `~/.config/sops` and `~/.secrets` are added to `persistDirs` so decrypted state survives across VM reboots (impermanence).

History: `50e80de feat: opencode api key` (first secret) → `84b7ab8` decryption fix → `e64a982 feat: forwarding age secret to vm` → `6b24dfc feat: sops key on vm`.

## Creating / rotating secrets

```bash
# First-time bootstrap for a host (creates/updates hosts/<domain>/<host>/secrets.yaml
# with masterPassword and writes the mkpasswd hash into the host decl):
angst bootstrap-secrets --host <host>        # sops + mkpasswd must be on PATH

# Add a new secret to an existing file (interactive edit, re-encrypted on save):
sops hosts/<domain>/<host>/secrets.yaml

# Declare it:
#   modules/secrets.nix  -> add to homeSecretDefs (target, mode)
#   then rebuild the host.
```

`angst bootstrap-secrets` reads the master password interactively (never echo), updates the encrypted file with `sops`, writes the sha-512 hash into the decl's `password` field, and unset its in-memory copy afterwards. The host will only decrypt once the age key is present at `~/.config/sops/age/keys.txt`.

## Project store (three layers)

Separate from per-host secrets, the **project store** keeps declared dev repos + their
`.env` across **three layers** (see the
[`git/projects` domain](domains.md#gitprojects--encrypted-project-store)):

- **Repo store** — `projects/{personal,work}/<opaque-id>/{metadata.yaml,env}` (committed,
  sops-binary **encrypted**). The transport: travels with the public repo, so a new machine
  that clones the repo has the metadata to clone its projects. Written only by
  `angst projects export`.
- **Working store** — `~/.secrets/angst/projects/{personal,work}/<opaque-id>/{metadata.yaml,env}`
  (fixed per-host, **decrypted plaintext**). Every runtime op reads/writes this directly (no
  sops at runtime). Seeded from the repo store at build time via `import`.
- **Clone root** — `~/projects/<name>`: cloned repo + decrypted `.env`, divergent per host.

- **Layout** — opaque ids are `openssl rand -hex 8` (16 chars, not name-derived); real
  project names and repo URLs appear only inside the encrypted repo store.
- **Binary encryption** — repo-store files are sops-encrypted with `--input-type binary
  --output-type binary`, so the whole plaintext (names, URLs, structure, comments) is one
  opaque blob and round-trips byte-exactly. Plaintext metadata is JSON `{name, repo}`.
- **Scope-isolated keys** — `personal/*` → the personal age key
  (`~/.config/sops/age/keys.txt` / `SOPS_AGE_KEY_FILE`); `work/*` → the work age
  key (`~/.config/sops/age/work-keys.txt` / `SOPS_WORK_AGE_KEY_FILE`, 0600). Work files
  list **only** the work recipient, so a work-key compromise can never decrypt personal
  secrets. Both keys are static, generated once, provisioned on every host through the
  `.config/sops` impermanence dir — this tool never rotates them.
- **Sops flow** — `import`/`export`/seed derive the recipient from the scope key file
  (`age-keygen -y`), encrypt/decrypt to a temp dir outside the stores. `export` is the only
  writer of the repo store; `sync`/`status` read the plaintext working store; the decrypted
  `.env` (0600) is the sync output at `~/projects/<name>/.env`.
- **Host selection by opaque id** — each host decl lists the store ids it syncs
  (`projects = [ "<opaque id>" ... ]`); names never appear in tracked files. Empty list =
  nothing synced. `~/projects` persistence is derived from this list in one place
  (`lib/build/mkNixos.nix`) — hosts never declare a persist dir.
- **Resilience** — a missing scope key, missing repo, no network, or any decrypt error
  skips that project with a warning and exits 0; `add --scope work` with a missing work key
  is the one **hard** error (misprovisioning, not a bootstrap case).
- **Leak prevention** — the repo store is always sops-encrypted (`check-projects-encrypted`
  + gitleaks guard it); plaintext lives only in the private `~/.secrets` working store (0700)
  and decrypted `.env` files; `sync`/`status` print no env values.

## Secret scanning (defense in depth)

- **Git hooks** (`githooks/`, install with `just install-hooks`): `pre-commit` runs `gitleaks git --pre-commit --staged --redact`; `pre-push` scans pushed ranges (`<remote_oid>..<local_oid>`, or all new commits for new refs) with gitleaks. Hooks use a host `gitleaks` or fall back to `nix run nixpkgs#gitleaks`.
- **`.gitleaks.toml`** — extends default rules with an `angst-plaintext-secret-value` rule targeting `secrets.yaml` and an `angst-projects-plaintext-secret-value` rule targeting `projects/.*`. Allowlists SOPS ciphertext (`ENC[AES256_GCM`), age blocks/public keys, and `README.md`/`pure.md`/`analysis.md`/`openwiki/`.
- **CI** (`.github/workflows/secret-scan.yml`) — gitleaks-action + trufflehog (`--results=verified,unknown`) on every push/PR; `fix: trufflehog` (HEAD) tuned the trufflehog args.
- **Flake check** (`checks/secrets.nix`) — `check-secrets-encrypted` fails if any tracked `secrets.yaml`/`secrets.yml` lacks a `sops:` block or `ENC[AES256_GCM` values; `check-projects-encrypted` asserts every `projects/**/metadata.yaml` + `projects/**/env` is sops-encrypted with no plaintext name/repo/URL content; `check-ftp-encrypted` asserts every `secrets/ftp/*` carries an age envelope with no plaintext server fields.

## Security rules for contributors

- Never commit plaintext secrets, age private keys, or `.dec` files (`.gitignore` covers `*.dec`, `*.agekey`, `node_modules`).
- Never paste secret values into chat/issue trackers; reference the env var names (`SOPS_AGE_KEY`, `SOPS_AGE_KEY_FILE`) or the `~/.secrets` targets instead.
- If a `secrets.yaml` is accidentally committed unencrypted, rotate the affected secret(s) immediately — gitleaks/trufflehog CI will flag it.
