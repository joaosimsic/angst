# Secrets

angst uses **sops-nix + age** to keep secrets out of the repository while making them available on every machine (including the disposable VM). Secrets are optional at build time and decrypted at runtime; if a machine can't decrypt, the system still builds and boots with defaults.

## Model

- **Per-host secret files**: `hosts/<domain>/<hostname>/secrets.yaml` (or `hosts/<hostname>/secrets.yaml`). Only `hosts/vm/secrets.yaml` and `hosts/personal/mint/secrets.yaml` exist today; `hosts/personal/nixos/` has none.
- **Encryption**: sops, age recipients configured in `.sops.yaml` (rules per `hosts/<domain>/.*/secrets.yaml` and `hosts/vm/secrets.yaml`). Files are checked at eval/CI time to contain a `sops:` block and `ENC[AES256_GCM` ciphertext.
- **Keys**: age keys at `~/.config/sops/age/keys.txt` (personal) and `~/.config/sops/age/work-keys.txt` (work), or `SOPS_AGE_KEY` / `SOPS_AGE_KEY_FILE` / `SOPS_WORK_AGE_KEY_FILE` env vars (used in CI/tooling). Keys are **not** committed (`.gitignore` ignores `*.agekey`).
- **Secret values** (declared in `modules/secrets.nix`):
  - `opencodeGoKey` → `~/.secrets/opencode-go-key` (mode 0600) — consumed by the opencode domain via `{file:~/.secrets/opencode-go-key}` (see `domains/agents/opencode/config/opencode.jsonc`).
  - `masterPassword` (NixOS hosts only) — the machine's master password: source of the login hash.

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

- **System** (`lib/build/mkNixos.nix`): `angst-bootstrap-secrets` oneshot service (before getty/display-manager) runs `mkpasswd -m sha-512` on the decrypted password and applies the hash to user + root via `usermod -p`. SSH keys are **not** managed here — they come from the shared, age-encrypted model below (`domains/remote/ssh/`).

This replaces the old approach of baking a password hash into the host decl; the hash in the decl is only the unseeded fallback (`changeme` default in `lib/resolve.nix`).

## Shared SSH keys (`secrets/ssh/`)

angst uses **one SSH key per scope** (personal / work), age-encrypted at rest in the repo, and provisions the same key to every host (physical machines and the disposable VM). A host does not generate its own identity; `angst-provision-ssh-key` decrypts the shared key at boot with the scope age key, so the same provider-authorized key is available everywhere — including non-interactive contexts like the boot-time projects sync.

| Scope | Age identity (decrypts) | Encrypted key in repo | Installed as |
|---|---|---|---|
| personal | `~/.config/sops/age/keys.txt` | `secrets/ssh/personal.ed25519.age` | `~/.ssh/id_ed25519` |
| work | `~/.config/sops/age/work-keys.txt` | `secrets/ssh/work.ed25519.age` | `~/.ssh/work_ed25519` |

- The SSH keys are **passphraseless**; protection at rest is the age-encrypted copy in the repo. Public keys are committed plaintext (`secrets/ssh/<scope>.ed25519.pub`).
- Encryption mirrors the project store's scope isolation: the personal file lists **only** the personal age recipient, the work file **only** the work recipient — a `work-age-key` compromise can never decrypt the personal SSH key.
- The age identities are the same sops age keys above; no new key material.
- The persistent ssh-agent (`domains/remote/ssh/ssh-agent.nix`) loads both passphraseless keys at login.

**Trade:** one host compromise exposes that scope's SSH identity everywhere it is authorized. Scope isolation bounds the blast radius to one identity; the age identity and SSH identity share the same authorization boundary. Do not extend a single scope's key to separable workloads.

### Generate / rotate

```bash
angst ssh-key generate --scope personal|work   # new .age + .pub, single scope recipient
angst ssh-key verify   --scope personal|work   # decrypts .age locally, compares with .pub
```

`generate` creates a fresh passphraseless `ed25519` pair in a temp dir (never in the repo), derives the recipient from the scope age key (`age-keygen -y`), writes `secrets/ssh/<scope>.ed25519.age` + `.pub` (`.pub` from the same keypair, so the two always match), and prints where to authorize it. Rotation is **authorize → verify → deploy → revoke**, never the reverse: authorize the new pub (additive), `verify` authentication, rebuild hosts to converge, then revoke the old pub. Revoking first creates a window where newly rebuilt hosts cannot authenticate.

### Provision at boot

A systemd oneshot `angst-provision-ssh-key` (unconditional — independent of sops-nix / `canDecrypt`) runs before `home-manager-<user>.service` and, on the VM, after `vm-age-key.service`. For each scope whose age key and `.age` file both exist, it decrypts to a temp file (mode `0600`), validates it is a private key (`ssh-keygen -y` round-trip), installs to `~/.ssh/<name>.tmp`, `mv`s over the destination (atomic — the destination is **never truncated before successful decryption**), and removes the temp plaintext. A missing age key or file skips that scope (resilient, never fatal). It re-decrypts on every boot, so hosts converge on rotation. Home-only hosts (`type = "home"`) run it as a user unit via `domains/remote/ssh/ssh-provision-home.nix`; the system unit (`domains/remote/ssh/system.nix`) is sandboxed (`NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, `ProtectHome=read-only`, `ReadWritePaths=~/.ssh`).

### Use at clone time

The projects sync clones each project with the matching scope key: `GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -i <scope key>"`, mirroring how the age key is selected per scope (`projects_keyfile`). Personal projects always use `personal-ssh-key`, work projects `work-ssh-key` — no `~/.ssh/config` guesswork. `accept-new` is a deliberate TOFU choice for fresh hosts/VM; physical hosts should eventually pin the provider host key instead.

### VM

The VM is just another host. `vm start` injects **only the host age keys** by default (`vm-core`'s shared-dir prep copies `keys.txt` → `age-keys.txt`; `vm-age-key` installs it as `keys.txt`) — if the VM only clones personal projects it never sees `work-age-key`. To run work projects too, copy `work-keys.txt` into the shared dir as well (an explicit capability, not a silent default). The VM mounts the repo (which carries `secrets/ssh/*.age`), so provisioning decrypts exactly the keys the VM is entitled to — the same age keys the host injected. Inbound SSH access from the host is **declarative**: `modules/vm/vm-profile.nix` bakes the committed `secrets/ssh/{personal,work}.ed25519.pub` into the VM's `authorized_keys` at build time; no host SSH key or agent material is forwarded at runtime. The host authenticates with its provisioned shared key; boot-time `angst-projects-sync` clones over SSH with the shared key — no agent forwarding, no interactive prompt.

### Checks

- Flake check **`check-ssh-keys`** (`checks/secrets.nix`) asserts each `secrets/ssh/*.age` carries an `age-encryption.org/v1` envelope, contains **no** `-----BEGIN OPENSSH PRIVATE KEY-----` plaintext, and has a matching `.pub` that is a valid OpenSSH public key (`ssh-keygen -lf`). It does **not** decrypt the `.age` — the scope age key is a secret CI never sees, so a decryption cross-check is impossible there. The envelope check is what makes the gitleaks allowlist safe: it independently establishes every file under that path really is age-encrypted.
- The `.pub` ↔ `.age` **correspondence** is verified with `angst ssh-key verify --scope <scope>` (decrypts locally with your age key and compares `ssh-keygen -y` output to the committed `.pub`); `generate` also derives `.pub` from the same keypair, so the two match by construction.
- `.gitleaks.toml` allowlists `secrets/ssh/.*\.age`; `.gitignore` ignores `*.agekey` / `*.dec` while the `.age` files are tracked.

### Security rules

- Never commit a plaintext private key, a decrypted temp copy, or a scope age key itself.
- A scope key compromise → rotate only that scope (`angst ssh-key generate --scope <scope>`), authorize → verify → deploy → revoke, and rebuild hosts.
- The passphraseless choice is a trade: anyone with a decrypted host filesystem can use the key. The repo-side age encryption and scope isolation are the controls; don't copy decrypted keys off their host.

## VM secret forwarding

The disposable VM decrypts the same secrets as the host **without baking keys into the image**:

- The host's **age keys** are copied into the VM's shared dir (`/tmp/shared` on the guest) by `vm-core`'s shared-dir prep when `vm start`/`vm restart` runs; `modules/vm/vm-profile.nix` installs them via `vm-age-key` → `~/.config/sops/age/keys.txt` (and, when a work key was injected, `work-keys.txt`).
- Inbound host→VM SSH auth is **declarative**: the committed shared scope public keys (`secrets/ssh/*.pub`) are baked into `~/.ssh/authorized_keys` at build time (`modules/vm/vm-profile.nix`). No host SSH keys and no ssh-agent are forwarded to the VM.
- `~/.config/sops` and `~/.secrets` are added to `persistDirs` so decrypted state survives across VM reboots (impermanence).

History: `50e80de feat: opencode api key` (first secret) → `84b7ab8` decryption fix → `e64a982 feat: forwarding age secret to vm` → `6b24dfc feat: sops key on vm` → *no host SSH key/agent forwarding: VM trusts the shared scope keys declaratively and authenticates the host with the provisioned shared key*.

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
- **`.gitleaks.toml`** — extends default rules with an `angst-plaintext-secret-value` rule targeting `secrets.yaml` and an `angst-projects-plaintext-secret-value` rule targeting `projects/.*`. Allowlists SOPS ciphertext (`ENC[AES256_GCM`), age blocks/public keys, `secrets/ssh/.*\.age`, `secrets/ftp/.*\.age`, and `README.md`/`pure.md`/`analysis.md`/`openwiki/` — no broad path allowlist on `projects/`.
- **CI** (`.github/workflows/secret-scan.yml`) — gitleaks-action + trufflehog (`--results=verified,unknown`) on every push/PR; `fix: trufflehog` (HEAD) tuned the trufflehog args.
- **Flake check** (`checks/secrets.nix`) — `check-secrets-encrypted` fails if any tracked `secrets.yaml`/`secrets.yml` lacks a `sops:` block or `ENC[AES256_GCM` values; `check-projects-encrypted` asserts every `projects/**/metadata.yaml` + `projects/**/env` is sops-encrypted (age envelope present) with no plaintext `name`/`repo`/URL/secret content; `check-ssh-keys` asserts every `secrets/ssh/*.age` is age-encrypted (envelope present, no plaintext private key) with a valid matching `.pub` (see [Shared SSH keys](#shared-ssh-keys-secretsssh)); `check-ftp-encrypted` asserts every `secrets/ftp/*` carries an age envelope with no plaintext server fields.

## Security rules for contributors

- Never commit plaintext secrets, age private keys, or `.dec` files (`.gitignore` covers `*.dec`, `*.agekey`, `node_modules`).
- Never paste secret values into chat/issue trackers; reference the env var names (`SOPS_AGE_KEY`, `SOPS_AGE_KEY_FILE`) or the `~/.secrets` targets instead.
- If a `secrets.yaml` is accidentally committed unencrypted, rotate the affected secret(s) immediately — gitleaks/trufflehog CI will flag it.
