# angst — Pure Flake Architecture

angst is a fully pure Nix flake. No `--impure`, no env vars, no gitignored config files. Every command is deterministic: same commit → same system. Machines are disposable — clone the repo and build.

## Philosophy

**Disposability.** A host is a directory in git. Wipe the disk, reinstall NixOS, `nixos-rebuild switch --flake .#nixos`, and you're back where you were. Nothing lives outside the repo. The only out-of-band artifact is the master password, which lives in your head. Even browser profiles are declared paths — they survive on `/persist` but aren't required to reconstruct the system.

**Purity.** The flake is a function of `git ls-files` only. `builtins.getEnv`, `builtins.currentTime`, and friends return nothing. `nix flake check` works bare. `nixos-rebuild list-generations` and `--rollback` are reliable. CI Just Works.

**Tracked config, encrypted secrets.** Machine identity (hostname, username, theme, profiles, monitors, toolchains) lives in plain Nix in `hosts/<domain>/<hostname>/default.nix` — version-controlled, diffable, reviewable. Secrets (DB credentials, API tokens) live in per-host sops-encrypted YAML files. Age keys are **never stored** — they are derived deterministically from the master password at activation time using a KDF keyed by domain. Personal machines and servers derive separate age identities from the same password so that compromising a server doesn't expose personal secrets. The repo is safe to make public — it contains no key material of any kind (not even passphrase-encrypted).

**Secrets are optional.** The system builds and boots fully functional without secrets. Tools, desktop, dotfiles, profiles — everything works. Secrets are added later, after the machine is running, via a one-time bootstrap command.

**Zero ceremony.** Adding a machine is `mkdir -p hosts/<domain>/<name>` + write `default.nix`. The flake auto-discovers hosts recursively. No flake.nix edits, no `--override-input`, no env vars, no key enrollment. Commands are bare:

```bash
sudo nixos-rebuild switch --flake .#nixos
home-manager switch --flake .#joao@nixos
home-manager switch --flake .#joao@linux
nix flake check
nix develop
nix run .#vm -- --host nixos start
```

## Directory structure

```
angst/
├── flake.nix                   # auto-discovers hosts/ directory (recursive)
├── hosts/
│   ├── personal/
│   │   ├── nixos/
│   │   │   ├── default.nix     #   machine identity (tracked, plain text)
│   │   │   ├── hardware.nix    #   nixos-generate-config output (tracked)
│   │   │   ├── disk.nix        #   disko layout (optional, tracked)
│   │   │   └── secrets.yaml    #   per-host sops secrets (personal domain)
│   │   ├── thonkpad/
│   │   │   ├── default.nix
│   │   │   └── secrets.yaml
│   │   └── linux/              # non-NixOS home-manager host, personal domain
│   │       ├── default.nix
│   │       └── secrets.yaml
│   ├── servers/
│   │   ├── vps/
│   │   │   ├── default.nix
│   │   │   └── secrets.yaml    # per-host sops secrets (server domain)
│   │   └── debian/
│   │       ├── default.nix
│   │       └── secrets.yaml
│   └── ci/                     # CI test host (minimal, no secrets)
│       └── default.nix
├── lib/
│   ├── read-config.nix         # pure function: config attrset → cfg
│   ├── flake/outputs.nix       # iterates hosts → nixosConfigurations + homeConfigurations
│   └── build/
│       ├── mkNixos.nix         # NixOS system builder (impermanence, sops, hardware)
│       └── mkHome.nix          # home-manager builder (sops)
├── profiles/                   # composable profile sets (base, desktop, server, vm, etc.)
├── toolchains/                 # auto-discovered toolchain definitions
├── domains/                    # auto-discovered application domain modules
├── themes/                     # auto-discovered theme definitions
└── .sops.yaml                  # age public keys, scoped by path pattern (personal + server)
```

Hosts are organized by **security domain** — `hosts/personal/` or `hosts/servers/` — which determines the age key derivation salt and sops encryption rules. The domain is implicit from the directory path: all hosts under `hosts/personal/` derive the personal age key, all hosts under `hosts/servers/` derive the server age key. No config field is needed. Each host has its own `secrets.yaml` — there are no shared secrets files. Per-host secrets follow the domain directory structure naturally.

**There are no age key files anywhere in the repo.** No `age.key`, no `.age` files, no passphrase-encrypted blobs. The repo contains only age **public** keys (in `.sops.yaml`, safe to track) and sops-encrypted secrets (also safe — encrypted at rest). The private keys live in volatile storage only: derived on demand from the master password, cached on persistent storage after first derivation, never written to the repo.

## How it works

### Host auto-discovery

`flake.nix` scans `hosts/` recursively using `builtins.readDir`. Security domain directories (`personal/`, `servers/`) and top-level entries (like `ci/`) are scanned; leaf directories with a `default.nix` become hosts. The host's `default.nix` is imported, enriched by `lib/read-config.nix` (defaults, domain scanning, toolchain resolution, theme indexing), and passed to `lib/flake/outputs.nix`, which builds `nixosConfigurations.<hostname>` for NixOS hosts and `homeConfigurations.<user>@<hostname>` for all hosts. The security domain is derived from the parent directory path — no config field needed.

Adding a machine:

```bash
mkdir -p hosts/personal/laptop
cp hosts/personal/nixos/default.nix hosts/personal/laptop/default.nix
# edit hosts/personal/laptop/default.nix — change hostname, monitors, profiles, etc.
# create hosts/personal/laptop/hardware.nix (nixos-generate-config)
git add hosts/personal/laptop
```

No flake.nix edits. No key enrollment. The new host appears in `nixosConfigurations.laptop`.

### Config → cfg pipeline

```
hosts/<domain>/<hostname>/default.nix  (plain Nix attrset, tracked)
    │
    ▼
lib/read-config.nix           (pure function)
    │  applies defaults
    │  scans domains/ themes/ toolchains/
    │  resolves profiles
    │
    ▼
cfg                            (enriched attrset)
    │
    ├──► mkNixos.nix  →  nixosConfigurations.<hostname>
    └──► mkHome.nix   →  homeConfigurations.<user>@<hostname>
```

`read-config.nix` is completely pure — it takes a config attrset and returns enriched cfg. No `builtins.getEnv`, no `builtins.currentTime`, no filesystem reads outside the flake source.

### Secrets with sops-nix

Each host has its own `hosts/<domain>/<hostname>/secrets.yaml`, encrypted to the domain's age public key. Secrets files are safe to track in git — they're encrypted at rest. There are no shared secrets files — each host owns its data. Adding a server host under `hosts/servers/` automatically uses the server age key; adding a personal host under `hosts/personal/` uses the personal key.

**Security domains.** Two age key pairs exist conceptually, but their private halves are never stored — only the public keys live in `.sops.yaml`:

- Personal domain — `hosts/personal/*/secrets.yaml` are encrypted to the personal age public key. Used for desktop machines, laptops. Contains serious secrets: personal API tokens, DB credentials, authentication material.
- Server domain — `hosts/servers/*/secrets.yaml` are encrypted to the server age public key. Used for VPS, CI runners. Contains operational secrets: deploy tokens, service credentials. If a server is compromised and its cached derived key is leaked, personal secrets are unaffected.

Both private keys are derived from the same master password using different domain-specific salts. The public keys are in `.sops.yaml`, scoped by domain path pattern, and are safe to commit to a public repo.

**The master password is the root of trust.** It is never stored anywhere — not in secrets, not in a hash field, not on disk. It exists only in the user's head and temporarily in RAM during activation. All keys flow from it:

```
master password (from user, in RAM only)
    │
    ├──► KDF(password, "angst-personal-v1")  → age identity (personal domain)
    │         │ derived at activation, cached on persistent storage
    │         │ sops-nix uses this to decrypt personal secrets
    │         │ verification: derived public key matches .sops.yaml
    │
    ├──► KDF(password, "angst-server-v1")    → age identity (server domain)
    │         │ only derived on server hosts
    │         │ same mechanism, different salt
    │
    ├──► mkpasswd -m sha-512                 → login password hash (NixOS)
    │
    └──► ssh-keygen -P                       → SSH key passphrase
```

**How derivation works.** The KDF takes the master password, a domain-specific salt (e.g. `"angst-personal-v1"`), and produces 32 deterministic bytes. Those bytes are clamped to form a valid X25519 scalar, then Bech32-encoded as an age private key (`AGE-SECRET-KEY-1...`). The corresponding public key (`age1...`) is derived and stored in `.sops.yaml`. Same password + same salt always produces the same key. Different salts produce unrelated keys.

**Password verification is implicit.** When the derived private key is used to decrypt secrets, sops-nix either succeeds (password was correct, derived key matches the public key in `.sops.yaml`) or fails (password was wrong, derived key is a different key). No separate hash check is needed.

**Password prompt.** Activation uses interactive `read -s` to prompt for the master password — no environment variables, no `$ANGST_PASSWORD`. This avoids leaking the password through process listings, shell tracing, or systemd journals. The prompt only appears when the derived age key is not already cached, or when running the explicit bootstrap command.

**Activation flow.** On every `switch`, sops-nix checks for a cached age identity:

1. **Cache hit.** A derived age identity exists on persistent storage (`/persist/angst/age-key` on NixOS, `~/.config/angst/age-key` on non-NixOS). sops-nix reads it directly. No prompt. Secrets decrypt silently.

2. **No secrets file.** If `secrets.yaml` doesn't exist for this host, sops-nix is configured with no default sops file. No key derivation happens. No prompt. The system runs normally without secrets.

3. **Cache miss, secrets exist.** Activation prompts for the master password (`read -s`), derives the domain's age identity via KDF, writes it to the cache location, and sops-nix proceeds to decrypt secrets. The derived identity is stored at the cache path for subsequent boots.

Once the password is in RAM (from the prompt), it is also used to:

- Derive the SHA-512 login password hash (NixOS only)
- Verify and update the SSH key passphrase
- Provision the SSH key if missing

The password is cleared from variables after all operations complete (`unset password`). It is never read from secrets — it comes from the user.

### Two-phase bootstrap: system first, secrets later

The system does not require secrets to build or boot. The bootstrap has two phases:

**Phase 1: Install the system.**

```bash
git clone <repo-url>
sudo nixos-rebuild switch --flake .#nixos
# or for non-NixOS:
home-manager switch --flake .#joao@linux
```

The system comes up fully functional — tools, desktop, dotfiles, profiles, domain configs, everything. No secrets yet. No password prompt. Login with the SHA-512 hash from the host config (or your host OS's existing password on non-NixOS).

**Phase 2: Add secrets.**

```bash
angst bootstrap-secrets --host nixos
```

This command prompts for the master password, derives the domain's age identity, verifies it against `.sops.yaml`, caches it on persistent storage, creates an empty `hosts/<domain>/<hostname>/secrets.yaml` encrypted with sops, provisions the SSH key with the password as passphrase, and updates the login password hash on NixOS. The user then edits `secrets.yaml` with `sops` to add their secrets and runs `nixos-rebuild switch` again. From that point on, sops-nix decrypts secrets on every activation.

This two-phase design means you never need secrets available at install time. You can set up a new machine, get comfortable with the tooling, and add secrets whenever convenient.

### SSH key enforcement at activation

The SSH key is decoupled from secrets. It's passphrase-protected with the master password but is not the secrets decryptor. On every `switch`, activation scripts verify and enforce:

1. **Key exists.** `~/.ssh/id_ed25519` must exist. If missing, it's generated with the master password as passphrase (requires a prior password prompt — either from a config with secrets triggering the flow, or from `angst bootstrap-secrets`).

2. **Passphrase matches.** `ssh-keygen -y -P "$password" -f ~/.ssh/id_ed25519` must succeed. If the key has no passphrase or a different one, activation sets it with `ssh-keygen -p`.

**Host key is independent.** The SSH host key (`/etc/ssh/ssh_host_ed25519`) is never copied from the user key. These serve different purposes — user keys authenticate outgoing connections, host keys authenticate incoming connections to sshd. Coupling them would mean a compromised user key can impersonate the server. On NixOS, the host key is generated by sshd and lives on `/persist/etc/ssh/`. On non-NixOS, it's managed by the host OS. angst only manages the user key.

### Opt-in impermanence

NixOS hosts can declare `persist.enable = true` to run on tmpfs `/`. The root filesystem is wiped on every reboot. Only explicitly declared paths survive:

```
/           (tmpfs, wiped on reboot)
/nix        (persistent partition — binary cache, no recompilation)
/boot       (persistent partition)
/persist    (persistent partition — deliberate state)
    ├── etc/ssh/                host identity
    ├── etc/machine-id          stable machine ID
    ├── angst/age-key           cached derived age identity (no prompt on reboot)
    └── home/<user>/
        ├── .ssh/               SSH key (passphrase-protected with master password)
        ├── .mozilla/           Firefox sessions, cookies, accounts
        ├── .config/google-chrome/  Chromium
        └── .local/share/keyrings/   libsecret passwords
```

Hosts with `persist.enable = false` use conventional filesystems. Non-NixOS hosts (`type = "home-manager"`) don't get impermanence at all — the host OS manages the filesystem.

### Total HDD loss scenario

```
1. Reinstall NixOS
2. Clone the repo (public or private, no key material inside)
3. sudo nixos-rebuild switch --flake .#nixos
4. System boots fully — tools, desktop, everything works
5. angst bootstrap-secrets --host nixos → enter master password
6. sops hosts/<domain>/<hostname>/secrets.yaml → add secrets
7. sudo nixos-rebuild switch --flake .#nixos
8. Done — secrets are live, SSH key provisioned, login set
```

The only out-of-band artifact is the password in your head. The repo itself is safe to clone on any machine, public or private.

## Host config reference

### `hosts/<domain>/<hostname>/default.nix` (NixOS)

```nix
{
  type = "nixos";          # "nixos" | "home-manager"
  system = "x86_64-linux";
  hostname = "nixos";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development"];
  toolchains = "*";          # "*" for all, or ["bash" "nix" "php"] for minimal

  monitors = {
    primary = {
      name = "DP-1";
      resolution = "1920x1080";
      refreshRate = 144;
      position = "0x0";
    };
  };

  db.connections = { };
  nixos = { keyboardLayout = "br-abnt2"; };
  home = { };
  env = { EDITOR = "nvim"; BROWSER = "firefox"; };
  shell = "";               # login shell name ("" = skip validation)

  sshAgent = {
    enable = true;
    keys = ["~/.ssh/id_ed25519"];
  };
  ssh = { };

  # Only meaningful for type = "nixos"
  persist = {
    enable = true;           # false → conventional filesystem
    root = "/persist";
    homeDirs = [
      ".mozilla"
      ".config/google-chrome"
      ".local/share/keyrings"
    ];
  };
}
```

### `hosts/<domain>/<hostname>/default.nix` (home-manager)

```nix
{
  type = "home-manager";      # produces only homeConfigurations
  system = "x86_64-linux";
  hostname = "linux";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development"];
  toolchains = "*";

  monitors = { };             # safe to leave empty — i3 auto-detects

  db.connections = { };
  home = { };
  env = { EDITOR = "nvim"; BROWSER = "firefox"; };
  shell = "";

  sshAgent = {
    enable = true;
    keys = ["~/.ssh/id_ed25519"];
  };
  ssh = { };

  # No persist, nixos, hardware.nix, disk.nix — those are NixOS-only.
}
```

### `hosts/personal/<hostname>/secrets.yaml`

Per-host secrets for a personal machine, encrypted to the personal age public key via sops.

```yaml
db:
  connections:
    dev:
      password: "db-password"
env:
  GITHUB_TOKEN: "ghp_..."
```

### `hosts/servers/<hostname>/secrets.yaml`

Per-host secrets for a server, encrypted to the server age public key via sops. Contains only what servers need — API tokens, DB credentials, but no personal desktop keys.

```yaml
db:
  connections:
    prod:
      password: "prod-db-password"
env:
  SOME_API_KEY: "sk-..."
```

The master password is never stored in secrets — it exists only in the user's head and temporarily in RAM during activation. Verification is implicit: if the derived age key successfully decrypts secrets, the password was correct.

### `.sops.yaml`

```yaml
creation_rules:
  - path_regex: hosts/servers/.*/secrets\.yaml$
    age: age1...<server-age-public-key>
  - path_regex: hosts/personal/.*/secrets\.yaml$
    age: age1...<personal-age-public-key>
```

Rules are ordered by priority (servers first). Each domain gets its own age key. Because the path pattern is anchored on the domain directory, there's no ambiguity — a host under `hosts/servers/` always uses the server key.

**Public keys are safe to commit.** These are public keys — they can only encrypt, never decrypt. The corresponding private keys are never stored anywhere; they are derived from the master password at activation time.

## Bootstrap (one-time per machine)

### Initial repo setup (one-time, by the repo owner)

Before any machine can use secrets, the repo owner must seed `.sops.yaml` with the age public keys and set the login password hash:

```bash
# Derive and print the personal age public key
angst derive-key --domain personal
# → age1... (paste into .sops.yaml)
# Derive and print the server age public key
angst derive-key --domain servers
# → age1... (paste into .sops.yaml)

# Hash the master password for login (NixOS hosts)
mkpasswd -m sha-512
# → $6$... (set as password in host config)

# Commit .sops.yaml and host configs
```

### Fresh machine bootstrap (per machine)

```bash
# Phase 1: install the system (no secrets needed)
git clone <repo-url>
sudo nixos-rebuild switch --flake .#nixos
# or: home-manager switch --flake .#joao@linux

# Phase 2: bootstrap secrets (whenever ready)
angst bootstrap-secrets --host nixos
# → prompts for master password
# → derives domain age identity, verifies against .sops.yaml
# → caches derived identity on persistent storage
# → creates empty secrets.yaml encrypted with sops
# → provisions SSH key with master password as passphrase
# → updates login password hash (NixOS)

# Edit secrets
sops hosts/<domain>/<hostname>/secrets.yaml
# → add your API tokens, DB passwords, etc.

# Apply
sudo nixos-rebuild switch --flake .#nixos
```

Every subsequent `switch` is silent — the cached derived age identity decrypts secrets without prompting.

## Non-NixOS (home-manager) hosts

Home-manager hosts have `type = "home-manager"` and produce only `homeConfigurations."<user>@<hostname>"`. They share the same profiles, toolchains, theme, domains, and secrets as NixOS hosts.

Fields and files ignored for home-manager hosts:

- `persist` — the host OS manages the filesystem
- `nixos` — NixOS-specific system config (keyboard layout, etc.)
- `hardware.nix`, `disk.nix` — NixOS hardware declaration

All non-NixOS distros are treated identically — Arch, Debian, Mint, Fedora, etc. The host OS manages the kernel, drivers, and system packages. home-manager manages user configuration, dotfiles, toolchains, and secrets. Prerequisites on the host:

- Nix (any installation method: official installer, nix-portable, distro package)
- home-manager (via nix or as a standalone)

No SSH key is required before the first switch — the bootstrap command provisions it.

### Server hosts (Debian, VPS, etc.)

Server hosts use `type = "home-manager"` and the `server` profile. They live under `hosts/servers/` — the security domain is implicit from the path. The SSH server (sshd) is managed by the host OS; angst only manages the SSH client config and the user key.

```nix
{
  type = "home-manager";
  system = "x86_64-linux";
  hostname = "debian";
  username = "joao";
  theme = "monochrome";
  profiles = ["base" "server"];
  toolchains = ["nix"];

  monitors = { };
  db.connections = { };
  home = { };
  env = { EDITOR = "nvim"; };
  shell = "";

  sshAgent = {
    enable = true;
    keys = ["~/.ssh/id_ed25519"];
  };
  ssh = {
    hosts = [
      { host = "github.com"; user = "git"; identityFile = "~/.ssh/id_ed25519"; }
    ];
  };
}
```

## Everyday usage

```bash
# Apply changes
sudo nixos-rebuild switch --flake .#nixos
home-manager switch --flake .#joao@nixos
home-manager switch --flake .#joao@debian

# Update flake inputs
nix flake update
sudo nixos-rebuild switch --flake .#nixos

# Run checks
nix flake check

# VM testing
nix run .#vm -- start          # uses NIX_DEFAULT_TARGET_HOST
NIX_DEFAULT_TARGET_HOST=thonkpad nix run .#vm -- start

# Dev shell (neovim, all toolchains, vm tools)
nix develop

# Minimal safe shell (neovim + toolchains, no qemu/ssh agent)
nix develop .#safe

# Domain config rendering
angst render --host nixos
angst watch   --host nixos
```

## Rotating secrets

### Change the master password

Changing the master password changes the derived age keys, so all secrets must be re-encrypted:

```bash
# 1. On any machine with the current password, decrypt all secrets
#    and re-encrypt with the new derived keys

# 2. Re-derive the public keys with the new password
angst derive-key --domain personal   # enter NEW password → update .sops.yaml
angst derive-key --domain servers    # enter NEW password → update .sops.yaml

# 3. Re-encrypt all secrets with sops
for f in hosts/personal/*/secrets.yaml hosts/servers/*/secrets.yaml; do
  sops updatekeys "$f"
done

# 4. Update login password hash
mkpasswd -m sha-512   # enter NEW password → update host configs

# 5. Clear cached age identities on all machines
rm /persist/angst/age-key            # NixOS
rm ~/.config/angst/age-key           # non-NixOS

# 6. Commit
git commit -am "rotate master password"
```

After committing, the next `switch` on each machine prompts for the new password (cache miss), derives the new age identity, re-caches it, and updates the SSH key passphrase.

### Rotate a domain's age key (without changing password)

Bump the version in the KDF salt to derive a new key from the same password:

```bash
# 1. Change the derivation version for the server domain
#    KDF salt: "angst-server-v1" → "angst-server-v2"
#    (this is a config change in the derivation script)

# 2. Derive and output the new public key
angst derive-key --domain servers --version v2  # → update .sops.yaml

# 3. Re-encrypt server secrets only
for d in hosts/servers/*/; do
  sops updatekeys "${d}secrets.yaml"
done

# 4. Clear cached identities on servers only
git commit -am "rotate server age key (v2)"
```

Personal machines are unaffected — only the server domain's derivation salt changed. No password change needed.

## CI

CI uses the `hosts/ci/` host — a minimal NixOS config with one toolchain, base profile, no secrets. Because `ci/` is at the top level (not under a domain directory), it has no secrets at all. No `cp local/config.nix.example` step needed. The flake evaluates purely and deterministically.

## Design constraints

- **`read-config.nix` is pure.** It takes config, returns cfg. No side effects, no env reads, no filesystem access outside the flake source.
- **Host config is tracked in git.** Machine identity is version-controlled. Changing your theme or adding a profile is a commit.
- **Secrets are encrypted, not hidden.** sops-encrypted files are safe to track in a public repo. Decryption happens at activation, never at eval time.
- **No key material in the repo.** Age public keys live in `.sops.yaml` (safe — they only encrypt). Age private keys are never stored — they are derived deterministically from the master password via KDF, cached on persistent storage, and never written to disk in the repo. The repo is safe to make fully public.
- **Compartments are security domains, not machines.** Two age key pairs (personal + server), both derived from the same master password with different KDF salts. Only public keys are in the repo. A server compromise that exposes the cached server-derived key decrypts only server secrets — personal secrets are isolated (different KDF salt, different key). Total HDD loss → clone repo, type password, done.
- **The master password is external input.** It is never stored in the secrets file — it exists only in the user's head and temporarily in RAM. Verification is implicit: the derived age key either decrypts secrets (correct password) or doesn't (wrong password). The single password powers four things — age key derivation, login, SSH key passphrase, and derivation identity verification — as a deliberate convenience tradeoff.
- **Secrets are optional, not required.** The flake builds and boots without any secrets file. `hasSecrets = builtins.pathExists secretsFile` gates everything sops-related. Tools, desktop, profiles, and domains all work without secrets. Secrets are added later via `angst bootstrap-secrets`.
- **The flake is a closed function.** Every input comes from git. Nothing depends on CWD, env vars, or which machine you're on. This is what makes `nix flake check` work, rollback reliable, and CI deterministic.
- **Hosts auto-discoverable.** `builtins.readDir` (recursive) means new hosts appear without touching `flake.nix`. No registration, no boilerplate.
- **Non-NixOS hosts are first-class.** `type = "home-manager"` hosts get the same structure, same secrets decryption, same outputs. They just don't get hardware config or impermanence.
- **SSH key is provisioned, not enrolled.** A single Ed25519 user key, passphrase-enforced with the master password. Used for SSH connections, not for sops. The SSH host key is independent — managed by sshd (NixOS) or the host OS (non-NixOS), never copied from the user key.

## Known concerns and implementation notes

### Password: external input, never stored

The master password is never stored anywhere — not in the sops-encrypted secrets file, not in a hash field, not on disk. It exists only in the user's head and temporarily in RAM during activation. Verification is implicit: if the derived age key successfully decrypts secrets (public key match in `.sops.yaml`), the password was correct. There is no separate hash to maintain or keep in sync.

The plaintext password (from user input) is used for SSH passphrase operations (`ssh-keygen -y -P "$password"`) and login hash derivation (`mkpasswd -m sha-512 "$password"`). It is cleared from variables immediately after use (`unset password`).

### Deterministic key derivation: properties and tradeoffs

Age keys are derived via KDF from the master password with a domain-specific salt. This means:

- **No key files to lose or leak.** There are no age private key files anywhere — not in the repo, not on disk (except the cache). The password is the sole root of trust.
- **Rotation via version bump.** To rotate a domain's age key, bump the version in the KDF salt (e.g. `"angst-personal-v1"` → `"angst-personal-v2"`). This produces a new, unrelated key from the same password. No key generation step is needed.
- **Password change → full re-encrypt.** Changing the master password changes all derived keys. All secrets must be decrypted with the old keys and re-encrypted with the new ones. This is a deliberate tradeoff: the password is the root, and changing it is a significant operation.
- **KDF parameters must be strong.** The derivation must use argon2id with high-cost parameters to resist brute-force. An attacker who obtains `.sops.yaml` and a `secrets.yaml` could attempt to brute-force the password offline.

### Cached derived key is the practical trust anchor

After the first `angst bootstrap-secrets`, the derived age key at `/persist/angst/age-key` (or `~/.config/angst/age-key`) is what actually decrypts secrets. At that point, security depends on disk encryption and OS permissions — not on knowledge of the master password. The password is only needed during the initial derivation handshake and for SSH key unlocks. This is an explicit tradeoff: the cached key eliminates password prompts on every boot, but means an attacker with filesystem access to `/persist` can read secrets without knowing the password.

### Password coupling: one secret, four purposes

The master password powers age key derivation, login, SSH key passphrase, and identity verification. This is an intentional convenience tradeoff: one secret to remember, one prompt to answer. If stronger compartmentalization is desired, each purpose could use a separate password at the cost of more memorization.

### Per-host secrets only — no shared fallback

With the nested domain directory structure, each host has its own `hosts/<domain>/<hostname>/secrets.yaml`. There are no shared secrets files, so no per-host-to-shared fallback is needed. Builders (`mkNixos.nix`, `mkHome.nix`) construct the secrets file path as `hosts/<domain>/<hostname>/secrets.yaml` based on the host's location in the directory tree.

### Interactive password prompt only (TTY required)

Activation uses `read -s` for the master password prompt. No `$ANGST_PASSWORD` environment variable, no `systemd-ask-password` pipe. Environment variables are visible to child processes and can appear in logs; a direct terminal prompt is safer.

Interactive prompts require a TTY. Remote deployment tools or non-interactive `nixos-rebuild` invocations may need an alternative. For automated deployments, consider pre-seeding the cached derived age key on persistent storage or using a separate automation-specific flow.

### Activation scripting must never leak the password

- `set +x` around any command that receives the password as argument
- No `echo "$password"` or equivalent, even in error paths
- `mkpasswd` output goes directly to the target file, never through the Nix store
- After all operations complete, explicitly clear the password variable: `unset password`

### Evaluation-time filesystem checks must live in activation scripts

`builtins.pathExists` on absolute system paths produces different results in sandboxed vs. unsandboxed evaluation, violating "same commit → same system." These checks must run at activation time, not in Nix module assertions:

| Module | Current check | Fix |
|---|---|---|
| `login-shell.nix` | `builtins.pathExists /usr/bin/nushell` in assertion | Validate shell in activation script via `which` or `getent` |
| `ssh-agent.nix` | `builtins.pathExists ~/.ssh/id_ed25519` to configure agent | Check key existence at activation |
| `is-qemu-vm.nix` | `builtins.pathExists /host/.../flake.nix` for VM detection | Detect at activation via `/sys/class/dmi/id/product_name` |

### repoPath derived at runtime

`repoPath` is not tracked in host config — it couples the flake to a specific checkout location and weakens disposability. Instead, derive the repo path at runtime:

- **VM tooling:** use the flake source path (`self`) or the `NIX_DISK_IMAGE` directory.
- **Activation scripts:** expect a well-known symlink or derive from the repo's own source path.
- **Domain config rendering:** use `$PWD` or the flake source path.

### Domain rendered config is generated, not source

Domain `config/` subdirectories contain theme-rendered output files. These are gitignored because:

- **Theme-dependent.** A host using theme `miasma` renders different config than one using `catppuccin-mocha`. Hosts must not cross-pollute the branch.
- **Generated, not authored.** The source of truth is the domain's `meta.nix` + `render.nix` + the host's selected theme. The rendered output is a build artifact.

Tracked in git: domain `.nix` modules, `meta.nix`, `render.nix`, and `config/` templates. Gitignored: the final rendered files in `domains/<category>/<name>/config/`.
