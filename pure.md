# angst — Pure Flake Architecture

angst is a fully pure Nix flake. No `--impure`, no env vars, no gitignored config files. Every command is deterministic: same commit → same system. Machines are disposable — clone the repo and build.

## Philosophy

**Disposability.** A host is a directory in git. Wipe the disk, reinstall NixOS, `nixos-rebuild switch --flake .#nixos`, and you're back where you were. Nothing lives outside the repo. The only out-of-band artifacts are the age keys, which the user provides at the standard sops-nix key path. Even browser profiles are declared paths — they survive on `/persist` but aren't required to reconstruct the system.

**Purity.** The flake is a function of `git ls-files` only. `builtins.getEnv`, `builtins.currentTime`, and friends return nothing. `nix flake check` works bare. `nixos-rebuild list-generations` and `--rollback` are reliable. CI Just Works.

**Tracked config, encrypted secrets.** Machine identity (hostname, username, theme, profiles, monitors, toolchains) lives in plain Nix in `hosts/<domain>/<hostname>/default.nix` — version-controlled, diffable, reviewable. Secrets (DB credentials, API tokens) live in per-host sops-encrypted YAML files. Age keys are standard sops-nix managed keys stored outside the repo at `~/.config/sops/age/keys.txt`. Personal machines and servers use separate age keys so that compromising a server doesn't expose personal secrets. The repo is safe to make public — it contains no key material of any kind.

**Secrets are optional.** The system builds and boots fully functional without secrets. Tools, desktop, dotfiles, profiles — everything works. Secrets are added later, after the machine is running, by placing the age key and creating `secrets.yaml`.

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
│   ├── resolve.nix             # pure function: host declaration → cfg
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

Hosts are organized by **security domain** — `hosts/personal/` or `hosts/servers/` — which determines the sops encryption rules and which age public key is used. The domain is implicit from the directory path: all hosts under `hosts/personal/` use the personal age public key, all hosts under `hosts/servers/` use the server age public key. No config field is needed. Each host has its own `secrets.yaml` — there are no shared secrets files. Per-host secrets follow the domain directory structure naturally.

**There are no age key files anywhere in the repo.** No `age.key`, no `.age` files, no passphrase-encrypted blobs. The repo contains only age **public** keys (in `.sops.yaml`, safe to track) and sops-encrypted secrets (also safe — encrypted at rest). Age private keys are managed by the user via sops-nix's native key path (`~/.config/sops/age/keys.txt`), outside the repo entirely.

## How it works

### Host auto-discovery

`flake.nix` scans `hosts/` recursively using `builtins.readDir`. Security domain directories (`personal/`, `servers/`) and top-level entries (like `ci/`) are scanned; leaf directories with a `default.nix` become hosts. The host's `default.nix` is imported, enriched by `lib/resolve.nix` (defaults, domain scanning, toolchain resolution, theme indexing), and passed to `lib/flake/outputs.nix`, which builds `nixosConfigurations.<hostname>` for NixOS hosts and `homeConfigurations.<user>@<hostname>` for all hosts. The security domain is derived from the parent directory path — no config field needed.

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
lib/resolve.nix           (pure function)
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

`resolve.nix` is completely pure — it takes a host declaration and returns enriched cfg. No `builtins.getEnv`, no `builtins.currentTime`, no filesystem reads outside the flake source.

### Secrets with sops-nix

Each host has its own `hosts/<domain>/<hostname>/secrets.yaml`, encrypted to the domain's age public key. Secrets files are safe to track in git — they're encrypted at rest. There are no shared secrets files — each host owns its data. Adding a server host under `hosts/servers/` automatically uses the server age key; adding a personal host under `hosts/personal/` uses the personal key.

**Security domains.** Two age key pairs exist, managed by the user via sops-nix:

- Personal domain — `hosts/personal/*/secrets.yaml` are encrypted to the personal age public key. Used for desktop machines, laptops. Contains serious secrets: personal API tokens, DB credentials, authentication material.
- Server domain — `hosts/servers/*/secrets.yaml` are encrypted to the server age public key. Used for VPS, CI runners. Contains operational secrets: deploy tokens, service credentials. If a server is compromised and its age key is leaked, personal secrets are unaffected.

Both keys are provided by the user at the sops-nix key path. The public keys are in `.sops.yaml`, scoped by domain path pattern, and are safe to commit to a public repo.

**The age keys are the root of trust for secrets.** The user provides age private keys at the sops-nix native key path (`~/.config/sops/age/keys.txt`). sops-nix discovers these keys automatically — no derivation, no prompt, no angst-specific key management. Two keys are needed:

- **Personal key** — placed on personal machines. Decrypts `hosts/personal/*/secrets.yaml`.
- **Server key** — placed on server machines. Decrypts `hosts/servers/*/secrets.yaml`.

**The master password** (for login and SSH passphrase) lives inside `secrets.yaml`, encrypted by the age key. It is only accessible once the age key is present and secrets are decrypted. Without the age key, the system still builds and boots fully functional — only secrets (including the master password) are unavailable.

**Secrets discovery is passive.** On every `switch`, sops-nix checks its native key path for age identities:

1. **Key present, secrets file exists.** sops-nix reads the age key, decrypts `secrets.yaml`. Secrets are available. The master password (from decrypted secrets) is used to set the login password hash and SSH key passphrase.

2. **No secrets file.** If `secrets.yaml` doesn't exist for this host, sops-nix is configured with no default sops file. Nothing happens. The system runs normally without secrets.

3. **Key missing, secrets exist.** sops-nix cannot decrypt secrets. The activation script handles this gracefully — no error, the system boots without secrets. Secrets are added later by providing the age key.

**Login and SSH passphrase from secrets.** When secrets are available, activation reads the master password from decrypted `secrets.yaml` and uses it to:

- Derive the SHA-512 login password hash (NixOS only)
- Verify and update the SSH key passphrase
- Provision the SSH key if missing

When secrets are unavailable, login uses the hash from the host config, and the SSH key has no passphrase. The user adds the master password to secrets later as part of bootstrap.

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

**Phase 2: Add the age key and secrets.**

```bash
# Generate age keys (one-time, anywhere)
age-keygen -o ~/.config/sops/age/keys.txt
# Add the public keys to .sops.yaml (personal + server)

# Create and edit secrets for this host
sops hosts/<domain>/<hostname>/secrets.yaml
```

The user places their age key at the sops-nix key path, adds the public keys to `.sops.yaml`, and creates an empty `secrets.yaml` encrypted with sops. They add their master password as a secret (e.g., `masterPassword: "..."`), along with API tokens and DB credentials. A follow-up `nixos-rebuild switch` decrypts secrets via sops-nix, sets the login password hash and SSH passphrase from the decrypted master password. From that point on, sops-nix decrypts secrets on every activation whenever the age key is present.

This two-phase design means you never need secrets available at install time. You can set up a new machine, get comfortable with the tooling, and add secrets whenever convenient.

### SSH key enforcement at activation

The SSH key is decoupled from secrets. When secrets are available, the master password from `secrets.yaml` is used as the SSH key passphrase. On every `switch`, activation scripts verify and enforce:

1. **Key exists.** `~/.ssh/id_ed25519` must exist. If missing, it's generated with the master password from secrets as passphrase (requires secrets to be available).

2. **Passphrase matches.** `ssh-keygen -y -P "$password" -f ~/.ssh/id_ed25519` must succeed, where `$password` is read from decrypted secrets. If the key has no passphrase or a different one, activation sets it with `ssh-keygen -p`.

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
5. Place age key at ~/.config/sops/age/keys.txt
6. sops hosts/<domain>/<hostname>/secrets.yaml → add secrets (including master password)
7. sudo nixos-rebuild switch --flake .#nixos
8. Done — secrets are live, SSH key provisioned, login set
```

The only out-of-band artifacts are the age keys, managed by the user. The repo itself is safe to clone on any machine, public or private.

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
masterPassword: "..."   # used for login hash and SSH passphrase
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
masterPassword: "..."   # used for login hash and SSH passphrase
db:
  connections:
    prod:
      password: "prod-db-password"
env:
  SOME_API_KEY: "sk-..."
```

The master password is stored in secrets — encrypted by the age key. It is used for login hash and SSH passphrase at activation time. Without the age key, secrets (including the master password) are unavailable.

### `.sops.yaml`

```yaml
creation_rules:
  - path_regex: hosts/servers/.*/secrets\.yaml$
    age: age1...<server-age-public-key>
  - path_regex: hosts/personal/.*/secrets\.yaml$
    age: age1...<personal-age-public-key>
```

Rules are ordered by priority (servers first). Each domain gets its own age key. Because the path pattern is anchored on the domain directory, there's no ambiguity — a host under `hosts/servers/` always uses the server key.

**Public keys are safe to commit.** These are public keys — they can only encrypt, never decrypt. The corresponding private keys are managed by the user at the sops-nix key path, outside the repo.

## Bootstrap (one-time per machine)

### Initial repo setup (one-time, by the repo owner)

Before any machine can use secrets, the repo owner must seed `.sops.yaml` with the age public keys and set the login password hash:

```bash
# Generate age keys (anywhere, one-time)
age-keygen -o ~/.config/sops/age/keys.txt
# Copy the public key (starts with age1...) into .sops.yaml for each domain

# Hash the master password for login (NixOS hosts)
mkpasswd -m sha-512
# → $6$... (set as password in host config)
# The same master password will be stored in secrets.yaml later

# Commit .sops.yaml and host configs
```

### Fresh machine bootstrap (per machine)

```bash
# Phase 1: install the system (no age key needed)
git clone <repo-url>
sudo nixos-rebuild switch --flake .#nixos
# or: home-manager switch --flake .#joao@linux

# Phase 2: add age key and secrets (whenever ready)
# Place the age key at the sops-nix native path
mkdir -p ~/.config/sops/age
cp /path/to/your/age-key.txt ~/.config/sops/age/keys.txt

# Create and edit secrets
sops hosts/<domain>/<hostname>/secrets.yaml
# → add your master password, API tokens, DB passwords, etc.

# Apply
sudo nixos-rebuild switch --flake .#nixos
```

Every subsequent `switch` is silent — sops-nix discovers the age key at the native path and decrypts secrets automatically.

## Non-NixOS (home-manager) hosts

Home-manager hosts have `type = "home-manager"` and produce only `homeConfigurations."<user>@<hostname>"`. They share the same profiles, toolchains, theme, domains, and secrets as NixOS hosts.

Fields and files ignored for home-manager hosts:

- `persist` — the host OS manages the filesystem
- `nixos` — NixOS-specific system config (keyboard layout, etc.)
- `hardware.nix`, `disk.nix` — NixOS hardware declaration

All non-NixOS distros are treated identically — Arch, Debian, Mint, Fedora, etc. The host OS manages the kernel, drivers, and system packages. home-manager manages user configuration, dotfiles, toolchains, and secrets. Prerequisites on the host:

- Nix (any installation method: official installer, nix-portable, distro package)
- home-manager (via nix or as a standalone)

No SSH key is required before the first switch — activation provisions it once secrets are available.

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

```bash
# 1. Edit secrets.yaml to update the master password
sops hosts/<domain>/<hostname>/secrets.yaml

# 2. Update login password hash
mkpasswd -m sha-512   # enter NEW password → update host configs

# 3. On next switch, activation reads the new master password from secrets
#    and updates the SSH key passphrase

# 4. Commit
git commit -am "rotate master password"
```

### Rotate an age key

Generate a new age key and update `.sops.yaml` with the new public key:

```bash
# 1. Generate new key
age-keygen -o ~/.config/sops/age/keys-new.txt

# 2. Update .sops.yaml with the new public key

# 3. Re-encrypt affected secrets
for d in hosts/servers/*/; do
  sops updatekeys "${d}secrets.yaml"
done

# 4. Replace the old key
mv ~/.config/sops/age/keys-new.txt ~/.config/sops/age/keys.txt

# 5. Commit
git commit -am "rotate server age key"
```

To rotate only the server key, only re-encrypt `hosts/servers/*/secrets.yaml`. Personal hosts are unaffected.

## CI

CI uses the `hosts/ci/` host — a minimal NixOS config with one toolchain, base profile, no secrets. Because `ci/` is at the top level (not under a domain directory), it has no secrets at all. No `cp local/config.nix.example` step needed. The flake evaluates purely and deterministically.

## Design constraints

- **`resolve.nix` is pure.** It takes a host declaration, returns cfg. No side effects, no env reads, no filesystem access outside the flake source.
- **Host config is tracked in git.** Machine identity is version-controlled. Changing your theme or adding a profile is a commit.
- **Secrets are encrypted, not hidden.** sops-encrypted files are safe to track in a public repo. Decryption happens at activation, never at eval time.
- **No key material in the repo.** Age public keys live in `.sops.yaml` (safe — they only encrypt). Age private keys are managed by the user at the sops-nix key path (`~/.config/sops/age/keys.txt`), outside the repo entirely. The repo is safe to make fully public.
- **Compartments are security domains, not machines.** Two age key pairs (personal + server), both managed by the user at the sops-nix key path. Only public keys are in the repo. A server compromise that exposes the server age key decrypts only server secrets — personal secrets are isolated (separate age key). Total HDD loss → clone repo, place age keys, done.
- **The master password is stored in secrets.** It lives in `secrets.yaml`, encrypted by the age key. Used for login hash and SSH passphrase. Without the age key, secrets are unavailable and the master password is not accessible — the system boots using the login hash from the host config.
- **Secrets are optional, not required.** The flake builds and boots without any secrets file. `hasSecrets = builtins.pathExists secretsFile` gates everything sops-related. Tools, desktop, profiles, and domains all work without secrets. Secrets are added later by providing the age key and creating `secrets.yaml` with `sops`.
- **The flake is a closed function.** Every input comes from git. Nothing depends on CWD, env vars, or which machine you're on. This is what makes `nix flake check` work, rollback reliable, and CI deterministic.
- **Hosts auto-discoverable.** `builtins.readDir` (recursive) means new hosts appear without touching `flake.nix`. No registration, no boilerplate.
- **Non-NixOS hosts are first-class.** `type = "home-manager"` hosts get the same structure, same secrets decryption, same outputs. They just don't get hardware config or impermanence.
- **SSH key is provisioned, not enrolled.** A single Ed25519 user key, passphrase-enforced with the master password. Used for SSH connections, not for sops. The SSH host key is independent — managed by sshd (NixOS) or the host OS (non-NixOS), never copied from the user key.

## Known concerns and implementation notes

### Password: stored in secrets

The master password is stored in encrypted secrets (inside `secrets.yaml`). It is used for login hash and SSH passphrase. Without the age key, secrets are unavailable and the master password is not accessible — the system still boots fully functional using the login hash from the host config.

When secrets are available, the master password is read from decrypted `secrets.yaml`. It is used for SSH passphrase operations (`ssh-keygen -y -P "$password"`) and login hash derivation (`mkpasswd -m sha-512 "$password"`). It is cleared from variables immediately after use (`unset password`).

### Age keys are user-managed

Age keys are standard sops-nix keys managed by the user, placed at `~/.config/sops/age/keys.txt`. There is no KDF derivation, no version bumps, no password-to-key mapping. The user generates keys with `age-keygen` or imports existing keys. Key rotation means generating a new key and re-encrypting affected secrets.

- **No derivation, no brute-force surface.** Because keys are not derived from a password, there is no KDF to attack. The security of secrets depends on the security of the age key file (disk encryption, OS permissions) — not on password entropy.

### Age key is the practical trust anchor

The age key at `~/.config/sops/age/keys.txt` is what decrypts secrets. Security depends on disk encryption and OS permissions. An attacker with filesystem access to the age key file can read secrets.

### Per-host secrets only — no shared fallback

With the nested domain directory structure, each host has its own `hosts/<domain>/<hostname>/secrets.yaml`. There are no shared secrets files, so no per-host-to-shared fallback is needed. Builders (`mkNixos.nix`, `mkHome.nix`) construct the secrets file path as `hosts/<domain>/<hostname>/secrets.yaml` based on the host's location in the directory tree.

### Activation scripting must never leak the password

When secrets are available, the master password is read from decrypted `secrets.yaml` in memory:

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
- **Generated, not authored.** The source of truth is the domain's `default.nix` + `render.nix` + the host's selected theme. The rendered output is a build artifact.

Tracked in git: domain `.nix` modules, `default.nix`, `render.nix`, and `config/` templates. Gitignored: the final rendered files in `domains/<category>/<name>/config/`.

## Refactoring checklist

Current state vs. target: flat `hosts/` (no domain nesting), `local/config.nix` exists with plaintext secrets, sops-nix wired but unseeded, no SSH key enforcement, flat sops rules, `read-config.nix` still needs rename.

### Phase 1: Rename resolve.nix

- [ ] `git mv lib/read-config.nix lib/resolve.nix`
- [ ] `flake.nix`: rename variable `readConfig` → `resolve`, import path `./lib/read-config.nix` → `./lib/resolve.nix`

### Phase 2: Host auto-discovery

- [ ] Restructure `hosts/` from flat to domain-nested:
  - `hosts/nixos/` → `hosts/personal/nixos/`
  - `hosts/ci/` stays at top level (no domain, no secrets)
  - Create `hosts/servers/` directory (empty or example host)
- [ ] Make `flake.nix` scan `hosts/` recursively:
  - Top-level dirs under `hosts/` are security domains or bare hosts
  - Domain dirs recurse: each subdirectory with `default.nix` is a host
  - Host's security domain inferred from parent path
- [ ] Update `lib/flake/outputs.nix` to receive domain info per host
- [ ] Pass domain to `mkNixos.nix` / `mkHome.nix` for sops file path construction

### Phase 3: Secrets

- [ ] Seed `.sops.yaml` with domain-scoped rules (replace flat `hosts/.*/` rule):
  - `hosts/personal/.*/secrets\.yaml$` → personal age public key
  - `hosts/servers/.*/secrets\.yaml$` → server age public key
- [ ] Create empty `secrets.yaml` for existing hosts (or document creation)
- [ ] `lib/build/mkNixos.nix`: sops file path → `hosts/<domain>/<hostname>/secrets.yaml`
- [ ] `lib/build/mkHome.nix`: same path derivation
- [ ] Remove `masterPassword` sentinel from `checks/password.nix`; update for sops-backed password flow

### Phase 4: SSH key enforcement

- [ ] `lib/build/mkNixos.nix` activation script:
  - Check `~/.ssh/id_ed25519` exists; generate if missing (using master password from decrypted secrets)
  - Verify passphrase matches with `ssh-keygen -y -P`
  - Set/correct passphrase with `ssh-keygen -p`
  - Skip gracefully when secrets are unavailable
- [ ] `lib/build/mkHome.nix`: equivalent activation logic

### Phase 5: Bootstrap tooling

- [ ] Add `angst bootstrap-secrets` subcommand (or repurpose `angst passwd`):
  - Creates `hosts/<domain>/<hostname>/secrets.yaml` encrypted with sops
  - Writes master password as `masterPassword` secret
- [ ] Update `justfile`: add `bootstrap` recipe, remove old `password` recipe

### Phase 6: Cleanup

- [ ] Delete `local/config.nix` — contains plaintext secrets; config is tracked per-host
- [ ] Delete `local/hardware.nix` — hardware config is per-host
- [ ] Delete `local/` directory if empty after removal
- [ ] Remove `angst passwd` subcommand from `scripts/angst.sh` — replaced by master password in secrets.yaml
- [ ] Remove `just password` recipe from `justfile`
- [ ] Remove any remaining `local/config.nix` references from `flake.nix`, builders, checks, and docs
- [ ] Delete `tools/shell/` input from `flake.nix` if unused after refactor
- [ ] Audit `lib/` for dead code: unused imports, unused `builtins.getEnv` calls, impure paths referencing the old flat structure
- [ ] Audit `checks/` for tests that depend on `local/config.nix` or the old flat `hosts/` layout
- [ ] Audit `.gitignore` — remove `local/config.nix`-related ignores, ensure `hosts/**/secrets.yaml` is tracked (encrypted, safe to commit)
- [ ] Audit `openwiki/` for stale references to `read-config.nix`, `local/config.nix`, flat `hosts/`, or age key derivation (regenerate if auto-generated)

### Phase 7: Validation

- [ ] Run `nix flake check` — no impure accesses, no `local/config.nix` dependency
- [ ] Test `sudo nixos-rebuild switch --flake .#nixos` before secrets bootstrap (Phase 1)
- [ ] Test with age key present and secrets.yaml populated (Phase 2)
- [ ] Verify `home-manager switch --flake .#<user>@<hostname>` for non-NixOS hosts
- [ ] Verify SSH key is provisioned and passphrase-enforced after bootstrap
- [ ] Verify login password is set from decrypted master password after bootstrap
- [ ] Verify secrets are unavailable (graceful skip) when age key is missing
