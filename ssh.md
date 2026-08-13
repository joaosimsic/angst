# SSH keys: shared, encrypted, scope-isolated

> **Status — implemented.** This describes the shared SSH-key model now in the
> tree: `angst ssh-key generate|verify`, the age-encrypted `secrets/ssh/` store,
> the boot-time `angst-provision-ssh-key` oneshot (system + home-only hosts),
> per-scope `GIT_SSH_COMMAND` in the projects sync, and the `check-ssh-keys`
> flake check + gitleaks allowlist. The per-host model it replaced
> (`angst-bootstrap-secrets` generating a fresh passphrase-protected
> `~/.ssh/id_ed25519`) is gone; the persistent ssh-agent
> (`domains/remote/ssh/ssh-agent.nix`) now loads the passphraseless shared keys.

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

## Terminology

Keep the two key types per scope distinct: "the personal key" is ambiguous
between them.

| Concept | Age identity (protects) | SSH identity (protected) |
|---|---|---|
| personal | `personal-age-key` → `~/.config/sops/age/keys.txt` | `personal-ssh-key` → `~/.ssh/id_ed25519` |
| work | `work-age-key` → `~/.config/sops/age/work-keys.txt` | `work-ssh-key` → `~/.ssh/work_ed25519` |

The age identity protects the SSH identity: a host's age key decrypts the
encrypted SSH key at boot, and nothing else.

## Model

| Scope | Age identity (decryption) | Encrypted shared SSH key | Installed as |
|---|---|---|---|
| personal | `personal-age-key` (`keys.txt`) | `secrets/ssh/personal.ed25519.age` | `personal-ssh-key` (`~/.ssh/id_ed25519`) |
| work | `work-age-key` (`work-keys.txt`) | `secrets/ssh/work.ed25519.age` | `work-ssh-key` (`~/.ssh/work_ed25519`) |

- The SSH keys are **passphraseless**; protection at rest comes from the
  age-encrypted copy in the repo. A passphrase would be unusable in non-interactive
  clones and, if stored alongside for auto-unlock, would provide no real security.
- The age identities are the **same sops age keys** already used for
  [secrets](openwiki/secrets.md) and the [project store](openwiki/secrets.md#project-store-projects):
  `personal-age-key` and `work-age-key`. No new key material is introduced.
- Encryption mirrors the scope isolation already used by the [project store](openwiki/secrets.md#project-store-projects):
  the personal SSH key file lists **only** the personal age recipient, the work
  file **only** the work recipient — a `work-age-key` compromise can never
  decrypt the personal SSH key.
- Public keys are committed as plaintext: `secrets/ssh/personal.ed25519.pub`,
  `secrets/ssh/work.ed25519.pub`.
- Rotation is independent per scope: regenerate one key, every host picks it up
  on next boot (provisioning always re-decrypts and overwrites).

### The trade: one SSH identity per scope, everywhere

Sharing one SSH key across every host is the fundamental trade of this design,
and it should be accepted consciously:

```text
host A compromise
        ↓
personal-ssh-key
        ↓
GitHub personal identity
        ↓
every host using that identity is effectively exposed
```

With the old per-host model, a host compromise exposed only that host's key.
With the shared model, **compromise of any one host exposes that scope's SSH
identity for every host**: anything a host can do with the age key, the repo's
encrypted SSH key, and its running filesystem, a fully compromised host can do
too.

This is the price of non-interactive provisioning and a usable disposable VM. It
is acceptable **only because** scope isolation bounds the blast radius to one
identity, and because the age identity and the SSH identity share the same
authorization boundary. Do not extend a single scope's key to workloads that
should be separable.

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
   `secrets/ssh/<scope>.ed25519.pub` into the repo, deriving the `.pub` from the
   generated keypair so the two always match,
4. prints the public key and where to authorize it (GitHub account for personal,
   work git provider for work),
5. cleans up the temp plaintext.

Rotation is **authorize → verify → deploy → revoke**, never the reverse:

1. `angst ssh-key generate --scope <scope>` — creates the new `.age` + `.pub`;
   the old key stays active everywhere,
2. **authorize** the new public key at the provider (additive; does not remove
   the old key),
3. **verify** authentication with the new key (e.g. `ssh -T` against the
   provider) before relying on it,
4. **deploy/rebuild** hosts so they converge on the new key,
5. **revoke** the old public key at the provider only after the new one is
   authorized and verified.

Revoking before the new key is authorized and verified creates a window where
the repo carries the new key but the provider still expects the old one, and
newly rebuilt hosts cannot authenticate. There is no rollback path once the old
key is revoked; step 3 is the last point where that is cheap.

### Provision at boot (every host)

A systemd oneshot `angst-provision-ssh-key` (unconditional — independent of
sops-nix / `canDecrypt`) runs before `home-manager-<user>.service` and, on the VM,
after `vm-age-key.service`.

This is a **second secret-decryption path outside sops-nix** (alongside the
projects-sync self-decryption of the [project store](openwiki/secrets.md#project-store-projects)),
and it understands the age-key layout on its own. The boundary is deliberate:
SSH provisioning must not depend on the normal secrets service. Keep it that
way, but harden the unit:

- a dedicated temporary directory,
- restrictive `UMask`,
- no logging of decrypted material, no `set -x`,
- cleanup of the temporary plaintext on every exit path, including failure,
- explicit dependency on the age-key installation service (`vm-age-key` on the
  VM) and ordering before anything that can invoke Git,
- `NoNewPrivileges=true` and a narrowly scoped filesystem/service sandbox where
  the rest of angst allows.

For each scope whose age key file **and** encrypted SSH key file exist, the
provisioning is **atomic and failure-safe**:

1. decrypt to a temp file under the dedicated dir, mode `0600`:
   `age -d -i <age key> -o <tmp> secrets/ssh/<scope>.ed25519.age`,
2. validate the result is a private key (`ssh-keygen -y` round-trip); on
   failure, exit without touching the destination,
3. install the temp file alongside the destination (`~/.ssh/<name>.tmp`),
4. `mv` (atomic rename) over the destination with mode `0600` and correct owner,
5. remove the temporary plaintext.

The destination is **never truncated before successful decryption**. A corrupted
`.age` file, bad age key, or interrupted provisioning must not turn a working
SSH identity into a missing one at boot.

- Missing age key or file → that scope is skipped (resilient, never fatal).
- Provisioning re-decrypts on every boot, so hosts converge automatically on
  rotation.

### Use at clone time (scope-correct)

The projects sync clones each project with the **matching scope key**:

- `projects_sync` sets, per scope,
  `GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -i <scope-ssh-key>"`,
  mirroring how the age key is selected per scope (`projects_keyfile`).
- `StrictHostKeyChecking=accept-new` tolerates empty `known_hosts` on fresh
  hosts/VM. This is a deliberate **TOFU** choice: the first connection is trusted
  without a pre-existing host key, so it does not protect against a first-
  connection MITM. Keep it for the disposable VM; physical hosts should
  eventually pin the Git provider's host key in `known_hosts` instead.
- Personal projects always authenticate with `personal-ssh-key`, work projects
  with `work-ssh-key` — no `~/.ssh/config` guesswork.

### VM

The VM is just another host, but it should receive **only the scope age keys
required by the workloads it runs** — the same scope-isolation principle applied
to the VM's capabilities, not a default of "everything".

- Today the VM runner injects **only the personal age key**
  (`tools/vm/scripts/lib/keys.sh` copies `keys.txt` → `age-keys.txt`; `vm-age-key`
  installs it as `keys.txt`). That is the right default: if the VM only clones
  personal projects, it never sees `work-age-key`, and a VM compromise cannot
  reach the work SSH identity.
- If the VM must also run work projects, extend the injection to carry
  `work-keys.txt` (and `vm-age-key` installs it as `work-keys.txt`) — an explicit
  capability, not a silent default.
- The VM mounts the repo (which carries `secrets/ssh/*.age`), so
  `angst-provision-ssh-key` decrypts the SSH keys the VM is entitled to, exactly
  as on a physical host.
- `vm-authorized-keys` still grants inbound SSH access from the host; boot-time
  `angst-projects-sync` clones over SSH using the shared key — no agent
  forwarding and no interactive prompt required.

## Checks

- A flake check asserts each `secrets/ssh/*.age` file carries an
  `age-encryption.org/v1` envelope and no `-----BEGIN OPENSSH PRIVATE KEY-----`
  plaintext.
- The same check **validates the `.pub` ↔ `.age` correspondence**: decrypting
  the `.age` file (with a test identity) must yield the public key committed as
  `.pub` (`ssh-keygen -y`). This catches accidental mismatches between the
  encrypted key and its plaintext public key.
- `.gitleaks.toml` allowlists `secrets/ssh/.*\.age` (age ciphertext is invisible
  to key rules, explicit allowlist for defense in depth). The envelope check is
  what makes the allowlist safe: it independently establishes that every file
  matching that pattern really is age-encrypted, so the allowlist cannot hide an
  unrelated plaintext secret placed under that path.
- `.gitignore` ignores `*.agekey` / `*.dec`; the `.age` files are meant to be
  tracked.

## Security rules

- Never commit a plaintext private key, a temp decrypted copy, or a scope age key
  itself.
- **One host compromise compromises the shared scope SSH identity.** A fully
  compromised host can decrypt the SSH key and act as the scope identity
  anywhere. Scope isolation is what limits this: the personal SSH identity and
  the work SSH identity are separable, and a VM holding only `personal-age-key`
  cannot reach the work identity. Do not blur that boundary.
- A scope key compromise → rotate only that scope
  (`angst ssh-key generate --scope <scope>`), following **authorize → verify →
  deploy → revoke**, and rebuild hosts.
- The SSH passphrase-less choice is a trade: anyone who obtains a decrypted host
  filesystem can use the key. The repo-side age encryption and scope isolation are
  the controls; do not copy decrypted keys outside their host.
