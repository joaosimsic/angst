# SSH keys: shared, encrypted, scope-isolated

> **Status — not yet implemented.** This is the target design for the shared
> SSH-key model. The current tree still runs the per-host model described in
> [Why](#why): `angst-bootstrap-secrets` generates a fresh passphrase-protected
> `~/.ssh/id_ed25519` per host, and a persistent ssh-agent
> (`domains/remote/ssh/ssh-agent.nix`) unlocks it at login. None of the
> following exist yet: `secrets/ssh/`, `angst ssh-key generate`,
> `angst-provision-ssh-key`, the `secrets/ssh` flake check, or the gitleaks
> allowlist. Everything below describes the intended state.

angst will use **one SSH key per scope** (personal / work), **age-encrypted at
rest in the repo**, and **provisions the same key to every host** (physical
machines and the disposable VM). A host does not generate its own identity; it
decrypts the shared key at boot with its scope age key, so the same
GitHub-authorized key is available everywhere — including non-interactive
contexts like the boot-time projects sync.

## Why

- The current model (`angst-bootstrap-secrets`) generates a **fresh
  `~/.ssh/id_ed25519` per host**, passphrase-protected by that host's master
  password; the shared model below replaces it. The result:
  - each machine had a key GitHub did not recognize (the VM in particular could
    never clone `angst` itself);
  - boot-time clones failed because a passphrase-protected key cannot be used
    non-interactively (no TTY, no loaded agent, and deliberately no mechanism to
    hand the master password to ssh).
- Fixing it with interactive prompts or agent forwarding couples the VM to the
  host's session. Sharing one encrypted key removes the dependency: every host
  that has the scope age key can decrypt the shared SSH key and clone on its own.

## Model

| Scope | Age key (identity for decryption) | Encrypted shared SSH key | Installed as |
|---|---|---|---|
| personal | `~/.config/sops/age/keys.txt` | `secrets/ssh/personal.ed25519.age` | `~/.ssh/id_ed25519` |
| work | `~/.config/sops/age/work-keys.txt` | `secrets/ssh/work.ed25519.age` | `~/.ssh/work_ed25519` |

- The SSH keys are **passphraseless**; protection at rest comes from the
  age-encrypted copy in the repo. A passphrase would be unusable in non-interactive
  clones and, if stored alongside for auto-unlock, would provide no real security.
- The scope age keys are the **same sops age keys** already used for
  [secrets](openwiki/secrets.md) and the [project store](openwiki/secrets.md#project-store-projects):
  `~/.config/sops/age/keys.txt` (personal) and
  `~/.config/sops/age/work-keys.txt` (work). No new key material is introduced.
- Encryption mirrors the scope isolation already used by the [project store](openwiki/secrets.md#project-store-projects):
  the personal key file lists **only** the personal age recipient, the work file
  **only** the work recipient — a work-key compromise can never decrypt the
  personal key.
- Public keys are committed as plaintext: `secrets/ssh/personal.ed25519.pub`,
  `secrets/ssh/work.ed25519.pub`.
- Rotation is independent per scope: regenerate one key, every host picks it up
  on next boot (provisioning always re-decrypts and overwrites).

## Lifecycle

### Generate / rotate

```bash
angst ssh-key generate --scope personal   # age-encrypts to the personal age recipient
angst ssh-key generate --scope work       # age-encrypts to the work age recipient
```

Each invocation:

1. creates a fresh passphraseless `ed25519` keypair in a temp dir (never inside
   the repo),
2. derives the recipient from the scope age key (`age-keygen -y`),
3. writes `secrets/ssh/<scope>.ed25519.age` (binary, age-encrypted) and
   `secrets/ssh/<scope>.ed25519.pub` into the repo,
4. prints the public key and where to authorize it (GitHub account for personal,
   work git provider for work),
5. cleans up the temp plaintext.

Authorizing a fresh key is a one-time, per-provider action. Adding it does **not**
remove existing keys; the old key can be revoked later.

### Provision at boot (every host)

A systemd oneshot `angst-provision-ssh-key` (unconditional — independent of
sops-nix / `canDecrypt`) runs before `home-manager-<user>.service` and, on the VM,
after `vm-age-key.service`:

- For each scope whose age key file **and** encrypted SSH key file exist:
  `age -d -i <scope age key> -o <tmp> secrets/ssh/<scope>.ed25519.age`, then
  install to `~/.ssh/id_ed25519` (personal) or `~/.ssh/work_ed25519` (work) with
  mode `0600` and correct owner.
- Missing age key or file → that scope is skipped (resilient, never fatal).

### Use at clone time (scope-correct)

The projects sync clones each project with the **matching scope key**:

- `projects_sync` sets, per scope,
  `GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -i <scope-key>"`,
  mirroring how the age key is selected per scope (`projects_keyfile`).
- `StrictHostKeyChecking=accept-new` tolerates empty `known_hosts` on fresh
  hosts/VM (TOFU for the first connection).
- Personal projects always authenticate with the personal key, work projects with
  the work key — no `~/.ssh/config` guesswork.

### VM

The VM is just another host: it gets **the same scope age keys as any machine**
(both `keys.txt` and `work-keys.txt`) and mounts the repo (which carries
`secrets/ssh/*.age`), so `angst-provision-ssh-key` decrypts **both** shared SSH
keys there exactly as on a physical host.

- `vm-age-key` installs the host's scope age keys (personal + work) into the VM;
  `vm-authorized-keys` still grants inbound SSH access from the host.
- Boot-time `angst-projects-sync` therefore clones over SSH using the shared key,
  no agent forwarding and no interactive prompt required.

## Checks

- A flake check asserts each `secrets/ssh/*.age` file carries an
  `age-encryption.org/v1` envelope and no `-----BEGIN OPENSSH PRIVATE KEY-----`
  plaintext.
- `.gitleaks.toml` allowlists `secrets/ssh/.*\.age` (age ciphertext is invisible
  to key rules, explicit allowlist for defense in depth).
- `.gitignore` ignores `*.agekey` / `*.dec`; the `.age` files are meant to be
  tracked.

## Security rules

- Never commit a plaintext private key, a temp decrypted copy, or the scope age
  key itself.
- A scope key compromise → rotate only that scope (`angst ssh-key generate
  --scope <scope>`), revoke the old public key at the provider, and rebuild hosts.
- The SSH passphrase-less choice is a trade: anyone who obtains a decrypted host
  filesystem can use the key. The repo-side age encryption and scope isolation are
  the controls; do not copy decrypted keys outside their host.
