# angst — Pure Flake Architecture

angst is a fully pure Nix flake. No `--impure`, no env vars, no gitignored config files. Every command is deterministic: same commit → same system. Machines are disposable — clone the repo and build.

## Philosophy

**Disposability.** A host is a directory in git. Wipe the disk, reinstall NixOS, `nixos-rebuild switch --flake .#nixos`, enter your password, and you're back where you were. Nothing lives outside the repo. The only out-of-band artifact is the master password, which lives in your head. Even browser profiles are declared paths — they survive on `/persist` but aren't required to reconstruct the system.

**Purity.** The flake is a function of `git ls-files` only. `builtins.getEnv`, `builtins.currentTime`, and friends return nothing. `nix flake check` works bare. `nixos-rebuild list-generations` and `--rollback` are reliable. CI Just Works.

**Tracked config, encrypted secrets.** Machine identity (hostname, username, theme, profiles, monitors, toolchains) lives in plain Nix in `hosts/<hostname>/default.nix` — version-controlled, diffable, reviewable. Secrets (master password, DB credentials, API tokens) live in a shared `hosts/secrets.yaml` — sops-encrypted to a single age key. That age key is passphrase-encrypted with the master password and tracked in git (`hosts/age-identity.key`). One key, one password, one repo — no per-machine enrollment.

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
│   ├── secrets.yaml            # shared sops secrets, encrypted to the master age key
│   ├── age-identity.key        # age private key, passphrase-encrypted with the master password
│   ├── nixos/                  # NixOS host
│   │   ├── default.nix         #   machine identity (tracked, plain text)
│   │   ├── hardware.nix        #   nixos-generate-config output (tracked)
│   │   └── disk.nix            #   disko layout (optional, tracked)
│   ├── linux/                  # non-NixOS (home-manager) host
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
└── .sops.yaml                  # one age public key (the master key)
```

One shared `hosts/secrets.yaml` for all hosts. A host can override by adding its own `hosts/<hostname>/secrets.yaml`, which takes precedence over the shared file. Per-host secrets files are optional — most hosts share the same secrets.

The age identity (`hosts/age-identity.key`) is a passphrase-encrypted age private key, generated once and tracked in git. The passphrase is the master password. On a fresh machine, activation prompts for the password, decrypts the identity, and caches it on persistent storage. On subsequent boots, the cached identity is used silently.

## How it works

### Host auto-discovery

`flake.nix` scans `hosts/` with `builtins.readDir`. Every subdirectory is a host (files like `secrets.yaml` and `age-identity.key` are skipped — only directories count). The host's `default.nix` is imported, enriched by `lib/read-config.nix` (defaults, domain scanning, toolchain resolution, theme indexing), and passed to `lib/flake/outputs.nix`, which builds `nixosConfigurations.<hostname>` for NixOS hosts and `homeConfigurations.<user>@<hostname>` for all hosts.

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

Secrets live in a shared `hosts/secrets.yaml`, encrypted to a single age key. A host-specific `hosts/<hostname>/secrets.yaml` can override the shared file (takes precedence if present). Otherwise, all hosts read from `hosts/secrets.yaml`.

**The master key.** There is exactly one age key pair. The private key is passphrase-encrypted with the master password and tracked in git as `hosts/age-identity.key`. The public key is listed in `.sops.yaml`. Every machine uses the same key — no per-machine enrollment, no `ssh-to-age`, no `sops updatekeys`.

```
hosts/age-identity.key          (age private key, passphrase-encrypted)
        │ encrypted with: master password (in your head)
        │ tracked in git
        │
        ▼
hosts/secrets.yaml              (sops-encrypted file)
        │ encrypted to: the master age public key
        │
        ▼
sops-nix at activation          (reads decrypted identity → decrypts secrets)
```

**Activation flow.** On every `switch`, a pre-activation step decrypts the age identity:

1. **Cache hit.** A decrypted identity exists on persistent storage (`/persist/angst/age-key` on NixOS, `~/.config/angst/age-key` on non-NixOS). Used directly. No prompt.

2. **Cache miss (fresh machine).** Activation prompts for the master password (via `systemd-ask-password` or `$ANGST_PASSWORD`). The password decrypts `hosts/age-identity.key` into the cache location. sops-nix uses it to decrypt secrets. The password from secrets is verified against the provided password. If they don't match, activation fails.

Once secrets are decrypted, the master password is available. It is used to:

- Derive the SHA-512 login password hash (NixOS only)
- Set the SSH key passphrase (if the key exists)
- Provision the SSH key if missing

### SSH key enforcement at activation

The SSH key is decoupled from secrets. It's passphrase-protected with the master password but is no longer the secrets decryptor. On every `switch`, after sops decrypts the master password, activation scripts verify and enforce:

1. **Key exists.** `~/.ssh/id_ed25519` must exist. If missing, it's generated with the master password as passphrase.

2. **Passphrase matches.** `ssh-keygen -y -P "$password" -f ~/.ssh/id_ed25519` must succeed. If the key has no passphrase or a different one, activation sets it with `ssh-keygen -p`. Changing the master password in `hosts/secrets.yaml` and switching applies the new passphrase to every machine's key.

3. **NixOS: host key matches.** If `/persist/etc/ssh/ssh_host_ed25519` content differs from `~/.ssh/id_ed25519`, activation copies the user key into place.

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

### `hosts/secrets.yaml`

Shared secrets, encrypted to the master age key via sops.

```yaml
password: "master-password"       # plaintext — SSH passphrase + system login
db:
  connections:
    dev:
      password: "db-password"
env:
  GITHUB_TOKEN: "ghp_..."
```

The `password` field is the master password: used as the SSH key passphrase and as the system login password. For NixOS, a SHA-512 hash is derived at activation time (`mkpasswd -m sha-512 "$password"`) so it never appears as plaintext in a config file.

### `.sops.yaml`

```yaml
creation_rules:
  - path_regex: hosts/.*/secrets\.yaml$
    age: age1...<single-master-key>
```

One key. No per-machine lines. Adding or removing machines doesn't touch this file.

## Bootstrap (one-time per machine)

```bash
# That's it. No key generation. No enrollment. No sops updatekeys.
# On first switch, activation prompts for the master password:
sudo nixos-rebuild switch --flake .#nixos
# Or for non-NixOS:
home-manager switch --flake .#joao@<hostname>
```

The first activation detects no cached age identity, prompts for the master password, decrypts `hosts/age-identity.key`, caches it, decrypts secrets, provisions the SSH key, and sets the login password. Every subsequent switch is silent.

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

## Everyday usage

```bash
# Apply changes
sudo nixos-rebuild switch --flake .#nixos
home-manager switch --flake .#joao@nixos
home-manager switch --flake .#joao@linux

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

# 2. Re-encrypt the age identity with the new passphrase
age -p -o hosts/age-identity.key < decrypted-age-key
# Enter new master password when prompted

# 3. Clear cached identities on all machines so they prompt for the new password
git commit -am "rotate master password"
```

After committing, the next `switch` on each machine prompts for the new password and re-caches the identity. The SSH key passphrase is also updated.

### Rotate the age key

```bash
# Generate a new age key pair
age-keygen -o /tmp/new-key
# Extract public key → update .sops.yaml
# Encrypt private key with master password:
age -p -o hosts/age-identity.key < /tmp/new-key
# Re-encrypt secrets to the new public key:
sops updatekeys hosts/secrets.yaml
git commit -am "rotate master age key"
```

## CI

CI uses the `hosts/ci/` host — a minimal NixOS config with one toolchain, base profile, no secrets. No `cp local/config.nix.example` step needed. The flake evaluates purely and deterministically.

## Design constraints

- **`read-config.nix` is pure.** It takes config, returns cfg. No side effects, no env reads, no filesystem access outside the flake source.
- **Host config is tracked in git.** Machine identity is version-controlled. Changing your theme or adding a profile is a commit.
- **Secrets are encrypted, not hidden.** sops-encrypted files are safe to track. Decryption happens at activation, never at eval time.
- **One key, one password.** A single age key, passphrase-encrypted with the master password, tracked in git. Every machine uses it. No per-machine enrollment, no `ssh-to-age`, no `.sops.yaml` management. Total HDD loss → clone repo, type password, done.
- **The flake is a closed function.** Every input comes from git. Nothing depends on CWD, env vars, or which machine you're on. This is what makes `nix flake check` work, rollback reliable, and CI deterministic.
- **Hosts auto-discoverable.** `builtins.readDir` means new hosts appear without touching `flake.nix`. No registration, no boilerplate.
- **Non-NixOS hosts are first-class.** `type = "home-manager"` hosts get the same structure, same secrets decryption, same outputs. They just don't get hardware config or impermanence.
- **SSH key is provisioned, not enrolled.** The SSH key is decoupled from secrets decryption. It's generated and passphrase-enforced at activation using the decrypted master password. It's for SSH connections, not for sops.

## Known concerns and implementation notes

### Password: plaintext in sops, hash at activation

The master password is stored as plaintext in `hosts/secrets.yaml` (sops-encrypted at rest). This is intentional — the plaintext is needed for SSH passphrase operations (`ssh-keygen -y -P "$password"`). The SHA-512 login hash is derived at activation time via `mkpasswd -m sha-512`. Implementation must NOT pre-hash the password before sops storage, or SSH passphrase enforcement becomes impossible.

### Shared secrets.yaml fallback

The builders (`mkNixos.nix`, `mkHome.nix`) must implement the shared-to-per-host fallback:

```
hosts/<hostname>/secrets.yaml → if missing, fall back to hosts/secrets.yaml
```

Currently only the per-host path is checked. The shared file is ignored.

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
