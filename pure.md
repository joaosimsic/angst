# angst — Pure Flake Architecture

angst is a fully pure Nix flake. No `--impure`, no env vars, no gitignored config files. Every command is deterministic: same commit → same system. Machines are disposable — clone the repo and build.

## Philosophy

**Disposability.** A host is a directory in git. Wipe the disk, reinstall NixOS, `nixos-rebuild switch --flake .#nixos`, enter your password, and you're back where you were. Nothing lives outside the repo. The only out-of-band artifact is the master password, which lives in your head. Even browser profiles are declared paths — they survive on `/persist` but aren't required to reconstruct the system.

**Purity.** The flake is a function of `git ls-files` only. `builtins.getEnv`, `builtins.currentTime`, and friends return nothing. `nix flake check` works bare. `nixos-rebuild list-generations` and `--rollback` are reliable. CI Just Works.

**Tracked config, encrypted secrets.** Machine identity (hostname, username, theme, profiles, monitors, toolchains) lives in plain Nix in `hosts/<hostname>/default.nix` — version-controlled, diffable, reviewable. Secrets (master password, DB credentials, API tokens) live in sops-encrypted YAML files, encrypted to age keys. Age private keys are passphrase-encrypted with the master password and tracked in git. Keys are scoped by trust tier — personal machines and servers use separate age identities so that compromising a server doesn't expose personal secrets. No per-machine enrollment.

**Zero ceremony.** Adding a machine is `mkdir hosts/<name>` + write `default.nix`. The flake auto-discovers hosts. No flake.nix edits, no `--override-input`, no env vars, no key enrollment. Commands are bare:

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
├── flake.nix                   # auto-discovers hosts/ directory
├── hosts/
│   ├── secrets.yaml            # shared sops secrets for personal machines
│   ├── secrets-server.yaml     # shared sops secrets for servers
│   ├── age-personal.key        # age private key (personal tier), passphrase-encrypted
│   ├── age-server.key          # age private key (server tier), passphrase-encrypted
│   ├── nixos/                  # NixOS host (personal tier)
│   │   ├── default.nix         #   machine identity (tracked, plain text)
│   │   ├── hardware.nix        #   nixos-generate-config output (tracked)
│   │   └── disk.nix            #   disko layout (optional, tracked)
│   ├── debian/                 # non-NixOS (home-manager) host, server tier
│   │   └── default.nix
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

Hosts belong to a **secrets tier** — `personal` or `server` — which determines which age key and shared secrets file they use. Each host can override with a per-host `hosts/<hostname>/secrets.yaml`, which takes precedence over the tier's shared file. Per-host secrets files are optional — most hosts share the same secrets within their tier.

Age private keys (`hosts/age-personal.key`, `hosts/age-server.key`) are passphrase-encrypted with the same master password, generated once, and tracked in git. On a fresh machine, activation prompts for the password, decrypts the identity, and caches it on persistent storage. On subsequent boots, the cached identity is used silently.

## How it works

### Host auto-discovery

`flake.nix` scans `hosts/` with `builtins.readDir`. Every subdirectory is a host (files like `secrets.yaml`, `secrets-server.yaml`, and `age-*.key` are skipped — only directories count). The host's `default.nix` is imported, enriched by `lib/read-config.nix` (defaults, domain scanning, toolchain resolution, theme indexing), and passed to `lib/flake/outputs.nix`, which builds `nixosConfigurations.<hostname>` for NixOS hosts and `homeConfigurations.<user>@<hostname>` for all hosts.

Adding a machine:

```bash
mkdir hosts/laptop
cp hosts/nixos/default.nix hosts/laptop/default.nix
# edit hosts/laptop/default.nix — change hostname, monitors, profiles, etc.
# create hosts/laptop/hardware.nix (nixos-generate-config)
git add hosts/laptop
```

No flake.nix edits. No key enrollment. The new host appears in `nixosConfigurations.laptop`.

### Config → cfg pipeline

```
hosts/<hostname>/default.nix  (plain Nix attrset, tracked)
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

Secrets live in shared YAML files, encrypted to tier-scoped age keys. A host-specific `hosts/<hostname>/secrets.yaml` can override the shared file (takes precedence if present). Otherwise, all hosts in a tier read from their shared file.

**Trust tiers.** Two age key pairs exist:

- `hosts/age-personal.key` — for personal machines (desktop, laptop). Secrets in `hosts/secrets.yaml`.
- `hosts/age-server.key` — for servers (Debian VPS, CI runners). Secrets in `hosts/secrets-server.yaml`.

Both are passphrase-encrypted with the same master password. The public keys are listed in `.sops.yaml`, scoped by path pattern. A server compromise that exposes the cached server age key decrypts only `hosts/secrets-server.yaml` — personal secrets are unaffected.

```
hosts/age-<tier>.key             (age private key, passphrase-encrypted)
        │ encrypted with: master password (in your head)
        │ tracked in git
        │ scoped: personal or server tier
        │
        ▼
hosts/secrets.yaml               (sops-encrypted, personal tier)
hosts/secrets-server.yaml        (sops-encrypted, server tier)
        │ encrypted to: the tier's age public key
        │
        ▼
sops-nix at activation           (reads decrypted identity → decrypts secrets)
```

**Password prompt.** Activation uses interactive `read -s` to prompt for the master password — no environment variables, no `$ANGST_PASSWORD`. This avoids leaking the password through process listings, shell tracing, or systemd journals.

**Activation flow.** On every `switch`, a pre-activation step decrypts the age identity:

1. **Cache hit.** A decrypted identity exists on persistent storage (`/persist/angst/age-key` on NixOS, `~/.config/angst/age-key` on non-NixOS). Used directly. No prompt.

2. **Cache miss (fresh machine).** Activation prompts for the master password (interactive `read -s`). The password decrypts `hosts/age-<tier>.key` into the cache location. sops-nix uses it to decrypt secrets. The password from decrypted secrets is verified against the provided password. If they don't match, activation fails.

Once secrets are decrypted, the master password is available. It is used to:

- Derive the SHA-512 login password hash (NixOS only)
- Set the SSH key passphrase (if the key exists)
- Provision the SSH key if missing

### SSH key enforcement at activation

The SSH key is decoupled from secrets. It's passphrase-protected with the master password but is not the secrets decryptor. On every `switch`, after sops decrypts the master password, activation scripts verify and enforce:

1. **Key exists.** `~/.ssh/id_ed25519` must exist. If missing, it's generated with the master password as passphrase.

2. **Passphrase matches.** `ssh-keygen -y -P "$password" -f ~/.ssh/id_ed25519` must succeed. If the key has no passphrase or a different one, activation sets it with `ssh-keygen -p`. Changing the master password in secrets and switching applies the new passphrase to every machine's key.

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
    ├── angst/age-key           cached decrypted age identity (no prompt on reboot)
    └── home/<user>/
        ├── .ssh/               SSH key (no passphrase prompt after first boot)
        ├── .mozilla/           Firefox sessions, cookies, accounts
        ├── .config/google-chrome/  Chromium
        └── .local/share/keyrings/   libsecret passwords
```

Hosts with `persist.enable = false` use conventional filesystems. Non-NixOS hosts (`type = "home-manager"`) don't get impermanence at all — the host OS manages the filesystem.

### Total HDD loss scenario

```
1. Reinstall NixOS
2. Clone the repo
3. sudo nixos-rebuild switch --flake .#nixos
4. Enter master password when prompted
5. Done — everything rebuilt from the repo alone
```

The age identity is passphrase-decrypted into the cache, secrets are decrypted, SSH key is provisioned, login password is set. The only thing you needed was the password in your head.

## Host config reference

### `hosts/<hostname>/default.nix` (NixOS)

```nix
{
  type = "nixos";          # "nixos" | "home-manager"
  system = "x86_64-linux";
  hostname = "nixos";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development"];
  toolchains = "*";          # "*" for all, or ["bash" "nix" "php"] for minimal
  secretsTier = "personal";  # "personal" (default) | "server" — selects age key + secrets file

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

### `hosts/<hostname>/default.nix` (home-manager)

```nix
{
  type = "home-manager";      # produces only homeConfigurations
  system = "x86_64-linux";
  hostname = "linux";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development"];
  toolchains = "*";
  secretsTier = "personal";   # "personal" (default) | "server" — selects age key + secrets file

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

### `hosts/secrets.yaml` (personal tier)

Shared secrets for personal machines, encrypted to the personal age key via sops.

```yaml
password: "master-password"       # plaintext — SSH passphrase + system login
db:
  connections:
    dev:
      password: "db-password"
env:
  GITHUB_TOKEN: "ghp_..."
```

### `hosts/secrets-server.yaml` (server tier)

Shared secrets for servers, encrypted to the server age key via sops. Contains only what servers need — API tokens, DB credentials, but no personal desktop keys.

```yaml
password: "server-password"       # may differ from personal if desired
db:
  connections:
    prod:
      password: "prod-db-password"
env:
  SOME_API_KEY: "sk-..."
```

The `password` field is the master password: used as the SSH key passphrase and as the system login password. For NixOS, a SHA-512 hash is derived at activation time (`mkpasswd -m sha-512 "$password"`) so it never appears as plaintext in a config file.

### `.sops.yaml`

```yaml
creation_rules:
  - path_regex: hosts/secrets-server\.yaml$
    age: age1...<server-age-public-key>
  - path_regex: hosts/.*/secrets\.yaml$
    age: age1...<personal-age-public-key>
```

The server rule is listed first — it matches the dedicated server secrets file. The wildcard rule matches per-host overrides (all personal by default). If a server host needs per-host secrets, its `secrets.yaml` would need an explicit `sops` metadata override or be encrypted to the server key manually.

## Bootstrap (one-time per machine)

```bash
# That's it. No key generation. No enrollment. No sops updatekeys.
# On first switch, activation prompts for the master password:
sudo nixos-rebuild switch --flake .#nixos
# Or for non-NixOS:
home-manager switch --flake .#joao@<hostname>
```

The first activation detects no cached age identity, prompts for the master password (interactive `read -s`), decrypts the appropriate `hosts/age-<tier>.key` based on the host's tier, caches it, decrypts secrets, provisions the SSH key, and sets the login password. Every subsequent switch is silent.

## Non-NixOS (home-manager) hosts

Home-manager hosts have `type = "home-manager"` and produce only `homeConfigurations."<user>@<hostname>"`. They share the same profiles, toolchains, theme, domains, and secrets as NixOS hosts.

Fields and files ignored for home-manager hosts:

- `persist` — the host OS manages the filesystem
- `nixos` — NixOS-specific system config (keyboard layout, etc.)
- `hardware.nix`, `disk.nix` — NixOS hardware declaration

All non-NixOS distros are treated identically — Arch, Debian, Mint, Fedora, etc. The host OS manages the kernel, drivers, and system packages. home-manager manages user configuration, dotfiles, toolchains, and secrets. Prerequisites on the host:

- Nix (any installation method: official installer, nix-portable, distro package)
- home-manager (via nix or as a standalone)

No SSH key is required before the first switch — the activation script provisions it using the master password from secrets.

### Server hosts (Debian, VPS, etc.)

Server hosts use `type = "home-manager"` and the `server` profile. They belong to the server secrets tier — using `hosts/age-server.key` and `hosts/secrets-server.yaml`. The SSH server (sshd) is managed by the host OS; angst only manages the SSH client config and the user key.

```nix
{
  type = "home-manager";
  system = "x86_64-linux";
  hostname = "debian";
  username = "joao";
  theme = "monochrome";
  profiles = ["base" "server"];
  toolchains = ["nix"];

  secretsTier = "server";    # uses age-server.key + secrets-server.yaml

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
# 1. Decrypt current secrets and re-encrypt with the new password
sops hosts/secrets.yaml
# Change the password field, save, exit

# 2. Re-encrypt both age identities with the new passphrase
age -p -o hosts/age-personal.key < decrypted-personal-key
age -p -o hosts/age-server.key < decrypted-server-key
# Enter new master password when prompted

# 3. Clear cached identities on all machines so they prompt for the new password
git commit -am "rotate master password"
```

After committing, the next `switch` on each machine prompts for the new password and re-caches the identity. The SSH key passphrase is also updated.

### Rotate a tier's age key

```bash
# Generate a new age key pair for the server tier
age-keygen -o /tmp/new-server-key
# Extract public key → update .sops.yaml server rule
# Encrypt private key with master password:
age -p -o hosts/age-server.key < /tmp/new-server-key
# Re-encrypt server secrets to the new public key:
sops updatekeys hosts/secrets-server.yaml
git commit -am "rotate server age key"
```

Personal machines are unaffected — only the server tier's key changes.

## CI

CI uses the `hosts/ci/` host — a minimal NixOS config with one toolchain, base profile, no secrets. No `cp local/config.nix.example` step needed. The flake evaluates purely and deterministically.

## Design constraints

- **`read-config.nix` is pure.** It takes config, returns cfg. No side effects, no env reads, no filesystem access outside the flake source.
- **Host config is tracked in git.** Machine identity is version-controlled. Changing your theme or adding a profile is a commit.
- **Secrets are encrypted, not hidden.** sops-encrypted files are safe to track. Decryption happens at activation, never at eval time.
- **Compartments are tiers, not machines.** Two age keys (personal + server), both passphrase-encrypted with the same master password, tracked in git. A server compromise decrypts only server secrets — personal secrets are isolated. Total HDD loss → clone repo, type password, done.
- **The flake is a closed function.** Every input comes from git. Nothing depends on CWD, env vars, or which machine you're on. This is what makes `nix flake check` work, rollback reliable, and CI deterministic.
- **Hosts auto-discoverable.** `builtins.readDir` means new hosts appear without touching `flake.nix`. No registration, no boilerplate.
- **Non-NixOS hosts are first-class.** `type = "home-manager"` hosts get the same structure, same secrets decryption, same outputs. They just don't get hardware config or impermanence.
- **SSH key is provisioned, not enrolled.** A single Ed25519 user key, passphrase-enforced at activation using the decrypted master password. Used for SSH connections, not for sops. The SSH host key is independent — managed by sshd (NixOS) or the host OS (non-NixOS), never copied from the user key.

## Known concerns and implementation notes

### Password: plaintext in sops, hash at activation

The master password is stored as plaintext in the sops-encrypted secrets file. This is intentional — the plaintext is needed for SSH passphrase operations (`ssh-keygen -y -P "$password"`). The SHA-512 login hash is derived at activation time via `mkpasswd -m sha-512`. Implementation must NOT pre-hash the password before sops storage, or SSH passphrase enforcement becomes impossible.

### Shared secrets.yaml fallback

The builders (`mkNixos.nix`, `mkHome.nix`) must implement the tier-scoped shared-to-per-host fallback:

```
hosts/<hostname>/secrets.yaml  →  if missing, fall back to hosts/secrets-<tier>.yaml
```

The tier is determined by the host's `secretsTier` config field (default: `"personal"`). Currently only the per-host path is checked.

### Interactive password prompt only

Activation uses `read -s` for the master password prompt. No `$ANGST_PASSWORD` environment variable, no `systemd-ask-password` pipe. Environment variables are visible to child processes and can appear in logs; a direct terminal prompt is safer.

### Activation scripting must never log the password

- `set +x` around any command that receives the password as argument
- No `echo "$password"` or equivalent, even in error paths
- `mkpasswd` output goes directly to the target file, never through the Nix store

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
