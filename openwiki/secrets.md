# Secrets

angst uses **age** to keep secrets out of the repository while making them available on every machine (including the disposable VM). Secrets are optional at build time and decrypted at runtime; if a machine can't decrypt, the system still builds and boots with defaults.

## Model

- **Per-host master password**: `secrets/master/<hostname>.age`, age-encrypted with the host's scope recipient. One file per NixOS host. Decrypted at boot by `angst set-password-hash`, which derives the sha-512 login hash.
- **App secrets**: `secrets/apps/<scope>/<slug>.age` (e.g. `secrets/apps/personal/opencode-go-key.age`), provisioned to `~/.secrets/<slug>` by `angst provision-app-secret`. Declared per host via `secrets = [ "<slug>" ... ]`.
- **Keys**: age keys at `~/.config/age/keys.txt` (personal) and `~/.config/age/work-keys.txt` (work), or `ANGST_AGE_KEY_FILE` / `ANGST_WORK_AGE_KEY_FILE` env vars (used in CI/tooling). Keys are **not** committed (`.gitignore` ignores `*.agekey`).
- **Secret values**:
  - `opencode-go-key` → `~/.secrets/opencode-go-key` (mode 0600) — consumed by the opencode domain via `{file:~/.secrets/opencode-go-key}` (see `domains/agents/opencode/config/opencode.jsonc`).
  - `masterPassword` (NixOS hosts only) — the machine's master password: source of the login hash.

## How it works (`modules/secrets.nix`)

`secrets.nix` is evaluated per host with `{ inputs, self, host, lib }`:

1. Locates `secrets/master/<hostname>.age` → `hasMasterAge`. `canDecrypt = hasMasterAge`.
2. The master-password boot service (`lib/build/mkNixos.nix`) is gated on the age file existing, so builds never fail on missing keys.
3. App secrets are wired via `modules/home/app-secrets.nix`, enabled when the host decl's `secrets` list is non-empty. `angst provision-app-secret` decrypts each `<slug>.age` with the scope age key and installs it at `~/.secrets/<slug>`.

The opencode API key therefore ends up at `~/.secrets/opencode-go-key` at activation time.

## Master password bootstrap

- **Create**: `angst bootstrap-master-password --host <host> [--scope personal|work]` reads the password interactively (no echo) and age-encrypts it to `secrets/master/<host>.age` with the scope recipient.
- **System** (`lib/build/mkNixos.nix`): `angst-bootstrap-secrets` oneshot service (before getty/display-manager) runs `angst set-password-hash`, which age-decrypts `secrets/master/<host>.age`, runs `mkpasswd -m sha-512` on the password, and applies the hash to user + root via `usermod -p`. SSH keys are **not** managed here — they come from the shared, age-encrypted model below (`domains/remote/ssh/`).

The hash in the host decl is only the unseeded fallback (`changeme` default in `lib/resolve.nix`); once `secrets/master/<host>.age` exists, the boot service overrides it.

## Shared SSH keys (`secrets/ssh/`)

angst uses **one SSH key per scope** (personal / work), age-encrypted at rest in the repo, and provisions the same key to every host (physical machines and the disposable VM). A host does not generate its own identity; `angst-provision-ssh-key` decrypts the shared key at boot with the scope age key, so the same provider-authorized key is available everywhere — including non-interactive contexts like the boot-time projects sync.

| Scope | Age identity (decrypts) | Encrypted key in repo | Installed as |
|---|---|---|---|
| personal | `~/.config/age/keys.txt` | `secrets/ssh/personal.ed25519.age` | `~/.ssh/id_ed25519` |
| work | `~/.config/age/work-keys.txt` | `secrets/ssh/work.ed25519.age` | `~/.ssh/work_ed25519` |

- The SSH keys are **passphraseless**; protection at rest is the age-encrypted copy in the repo. Public keys are committed plaintext (`secrets/ssh/<scope>.ed25519.pub`).
- Encryption mirrors the project store's scope isolation: the personal file lists **only** the personal age recipient, the work file **only** the work recipient — a `work-age-key` compromise can never decrypt the personal SSH key.
- The age identities are the same age keys above; no new key material.
- The persistent ssh-agent (`domains/remote/ssh/ssh-agent.nix`) loads both passphraseless keys at login.

**Trade:** one host compromise exposes that scope's SSH identity everywhere it is authorized. Scope isolation bounds the blast radius to one identity; the age identity and SSH identity share the same authorization boundary. Do not extend a single scope's key to separable workloads.

### Generate / rotate

```bash
angst ssh-key generate --scope personal|work   # new .age + .pub, single scope recipient
angst ssh-key verify   --scope personal|work   # decrypts .age locally, compares with .pub
```

`generate` creates a fresh passphraseless `ed25519` pair in a temp dir (never in the repo), derives the recipient from the scope age key (`age-keygen -y`), writes `secrets/ssh/<scope>.ed25519.age` + `.pub` (`.pub` from the same keypair, so the two always match), and prints where to authorize it. Rotation is **authorize → verify → deploy → revoke**, never the reverse: authorize the new pub (additive), `verify` authentication, rebuild hosts to converge, then revoke the old pub. Revoking first creates a window where newly rebuilt hosts cannot authenticate.

### Provision at boot

A systemd oneshot `angst-provision-ssh-key` (unconditional — independent of `canDecrypt`) runs before `home-manager-<user>.service` and, on the VM, after `vm-age-key.service`. For each scope whose age key and `.age` file both exist, it decrypts to a temp file (mode `0600`), validates it is a private key (`ssh-keygen -y` round-trip), installs to `~/.ssh/<name>.tmp`, `mv`s over the destination (atomic — the destination is **never truncated before successful decryption**), and removes the temp plaintext. A missing age key or file skips that scope (resilient, never fatal). It re-decrypts on every boot, so hosts converge on rotation. Home-only hosts (`type = "home"`) run it as a user unit via `domains/remote/ssh/ssh-provision-home.nix`; the system unit (`domains/remote/ssh/system.nix`) is sandboxed (`NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, `ProtectHome=read-only`, `ReadWritePaths=~/.ssh`).

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

- The host's **age keys** are copied into the VM's shared dir (`/tmp/shared` on the guest) by `vm-core`'s shared-dir prep when `vm start`/`vm restart` runs; `modules/vm/vm-profile.nix` installs them via `vm-age-key` → `~/.config/age/keys.txt` (and, when a work key was injected, `work-keys.txt`).
- Inbound host→VM SSH auth is **declarative**: the committed shared scope public keys (`secrets/ssh/*.pub`) are baked into `~/.ssh/authorized_keys` at build time (`modules/vm/vm-profile.nix`). No host SSH keys and no ssh-agent are forwarded to the VM.
- `~/.config/age` and `~/.secrets` are added to `persistDirs` so decrypted state survives across VM reboots (impermanence).

History: `50e80de feat: opencode api key` (first secret) → `84b7ab8` decryption fix → `e64a982 feat: forwarding age secret to vm` → `6b24dfc feat: sops key on vm` → *no host SSH key/agent forwarding: VM trusts the shared scope keys declaratively and authenticates the host with the provisioned shared key*.

## Creating / rotating secrets

```bash
# First-time bootstrap for a host (age-encrypts the master password to
# secrets/master/<host>.age; the boot service derives the login hash):
angst bootstrap-master-password --host <host>        # age + age-keygen must be on PATH

# Declare app secrets in the host decl:
#   secrets = [ "opencode-go-key" "cursor-api-key" ];
#   then rebuild the host.
```

`angst bootstrap-master-password` reads the master password interactively (never echo), age-encrypts it to `secrets/master/<host>.age`, and unset its in-memory copy afterwards. The host will only decrypt once the age key is present at `~/.config/age/keys.txt`.

## Project store (tarball + vault/age)

Separate from per-host secrets, the **project store** keeps declared dev repos + their
`.env` (see the [`git/projects` domain](domains.md#gitprojects--encrypted-project-store)).
Unlike some older secret stores, the project store is **age/vault**, not sops:

- **Repo store** — `projects/{personal,work}.tar.age` (committed, **age-encrypted**). Each
  tarball holds the whole `<scope>/<id>/{metadata.json,.env}` tree. The transport: travels
  with the public repo so a new machine has the metadata to clone its projects. Rewritten
  only by the manual `vault` edit flow (`angst vault decrypt --dir` → edit → `angst vault
  encrypt --dir`), then committed.
- **Working store** — `~/.secrets/projects/{personal,work}/<id>/{metadata.json,.env}` (fixed
  per-host, **decrypted plaintext**). Runtime ops read this directly (no age at runtime).
  Seeded from the tarballs at build time via `import`.
- **Clone root** — `~/projects/<name>`: cloned repo + decrypted `.env`, divergent per host.

- **Layout** — each project is a folder `<slug>/` inside the scope tarball, where `<slug>` is
  any identifier you choose, including nested paths (e.g. `dotfiles`, `website`, or `intelligence/backend`);
  the store is discovered recursively so a project may sit at any depth, and its id is the relative
  path under the scope. Real project names and repo
  URLs appear only inside the encrypted tarball (in `metadata.json`), never in tracked files.
- **Tarball encryption** — `vault encrypt --dir` tars the scope dir and age-encrypts it, so
  the whole plaintext tree (names, URLs, structure, comments) is one opaque blob that
  round-trips byte-exactly. Plaintext metadata is JSON `{name, repo}`.
- **Scope-isolated keys** — `personal.tar.age` → the personal age key
  (`~/.config/age/keys.txt` / `ANGST_AGE_KEY_FILE`); `work.tar.age` → the work age
  key (`~/.config/age/work-keys.txt` / `ANGST_WORK_AGE_KEY_FILE`, 0600). The work
  tarball lists **only** the work recipient, so a work-key compromise can never decrypt
  personal projects. Both keys are static, generated once, provisioned on every host through
  the `.config/age` impermanence dir — this tool never rotates them.
- **Vault flow** — `import` decrypts each `projects/<scope>.tar.age` into the working store
  (`vault.DecryptTarball`); `sync` reads the plaintext working store and materializes
  `.env` (0600) at `~/projects/<name>/.env`. The repo tarballs only change via the manual
  `vault` edit flow above. Host selection (`ANGST_PROJECTS_ONLY`) still happens in `sync`,
  not `import`.
- **Host selection by slug** — each host decl lists the slugs it syncs
  (`projects = [ "<slug>" ... ]`); the real name never appears in tracked files (it lives only
  in the encrypted `metadata.json`). Empty list =
  nothing synced. `~/projects` persistence is derived from this list in one place
  (`lib/build/mkNixos.nix`) — hosts never declare a persist dir.
- **Resilience** — a missing scope key, missing tarball, no network, or any decrypt error
  skips that project with a warning and exits 0; nothing fails a build or boot.
- **Leak prevention** — the repo store is always age-encrypted (`check-projects-encrypted`
  + gitleaks guard it); the decrypted scope dirs (`projects/personal/`, `projects/work/`) are
  gitignored so an in-place decrypt never stages plaintext; plaintext lives only in the
  private `~/.secrets` working store (0700) and decrypted `.env` files; `sync` prints no env
  values.

## Secret scanning (defense in depth)

- **Git hooks** (`githooks/`, install with `just install-hooks`): `pre-commit` runs `gitleaks git --pre-commit --staged --redact`; `pre-push` scans pushed ranges (`<remote_oid>..<local_oid>`, or all new commits for new refs) with gitleaks. Hooks use a host `gitleaks` or fall back to `nix run nixpkgs#gitleaks`.
- **`.gitleaks.toml`** — extends default rules with an `angst-plaintext-secret-value` rule targeting `secrets.yaml` and `secrets/master/` and an `angst-projects-plaintext-secret-value` rule targeting `projects/.*`. Allowlists age blocks/public keys, `secrets/ssh/.*\.age`, `secrets/ftp/.*\.age`, and `README.md`/`pure.md`/`analysis.md`/`openwiki/` — no broad path allowlist on `projects/`.
- **CI** (`.github/workflows/secret-scan.yml`) — gitleaks-action + trufflehog (`--results=verified,unknown`) on every push/PR; `fix: trufflehog` (HEAD) tuned the trufflehog args.
- **Flake check** (`checks/secrets.nix`) — `check-secrets-encrypted` fails if any `secrets/master/*.age` lacks an `age-encryption.org/v1` envelope; `check-projects-encrypted` asserts every `projects/*.tar.age` is age-encrypted (envelope present); `check-ssh-keys` asserts every `secrets/ssh/*.age` is age-encrypted (envelope present, no plaintext private key) with a valid matching `.pub` (see [Shared SSH keys](#shared-ssh-keys-secretsssh)); `check-ftp-encrypted` asserts every `secrets/ftp/*` carries an age envelope with no plaintext server fields.

## Security rules for contributors

- Never commit plaintext secrets, age private keys, or `.dec` files (`.gitignore` covers `*.dec`, `*.agekey`, `node_modules`).
- Never paste secret values into chat/issue trackers; reference the env var names (`ANGST_AGE_KEY_FILE`, `ANGST_WORK_AGE_KEY_FILE`) or the `~/.secrets` targets instead.
- If a `secrets.yaml` is accidentally committed unencrypted, rotate the affected secret(s) immediately — gitleaks/trufflehog CI will flag it.
