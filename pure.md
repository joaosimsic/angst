# Pure Flake Migration

This guide describes how to convert angst from an impure flake (`builtins.getEnv "PWD"` pattern) to a pure flake, keeping the single `local/config.nix` file as a per-machine interface — gitignored, not tracked, no extra flags needed.

## Concept

The `path:` flake input fetcher copies a directory to the Nix store **without filtering by gitignore**. Unlike `self` (which uses `git ls-files` and excludes untracked files), a `path:` input exposes the full directory contents. By declaring `local/` as a `path:` input with `flake = false`, the flake can import `local/config.nix` without `builtins.getEnv` and without `--impure`.

```
angst/                       # flake repo (pure, tracked by git)
├── flake.nix                # declares inputs.local-config = path:./local
├── local/
│   ├── config.nix           # per-machine identity (gitignored)
│   ├── config.nix.example   # template (tracked)
│   ├── hardware.nix         # generated hardware config (gitignored)
│   └── disk.nix             # disko layout (gitignored)
├── lib/read-config.nix      # reads from inputs.local-config, not builtins.getEnv
└── ...
```

No new directories. No `ANGST_CONFIG` env var. No `--override-input`. Build commands are bare:

```bash
sudo nixos-rebuild switch --flake .#current
home-manager switch --flake .#current
nix flake check
nix develop
```

## Step-by-step

### 1. Add local-config input to flake.nix

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    local-config = {
      url = "path:./local";
      flake = false;
    };

    vm = {
      url = "./tools/vm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    shell = {
      url = "./tools/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, local-config, ... }@inputs:
    let
      themesLib = import ./themes/default.nix { lib = inputs.nixpkgs.lib; };
      pure = import ./lib/read-config.nix { inherit inputs themesLib; };
      inherit (pure) cfg;
      pkgs = import nixpkgs {
        inherit (cfg) system;
        config = import ./lib/nixpkgs-config.nix;
      };
      profiles = import ./profiles/default.nix {
        inherit (cfg) profiles;
        inherit (pkgs) lib;
        inherit (cfg) scan;
      };
    in
    import ./lib/flake/outputs.nix {
      inherit
        self
        inputs
        cfg
        profiles
        ;
    };
}
```

`flake = false` means Nix won't try to interpret it as a flake — it exposes the directory path the outputs function can import from. The name `local-config` is arbitrary; `path:./local` makes it resolve to the `local/` directory in the flake repo.

### 2. Rewrite lib/read-config.nix

Replace `builtins.getEnv "PWD"` with `${inputs.local-config}/config.nix`:

**`lib/read-config.nix`:**

```nix
{
  inputs,
  themesLib,
}:

let
  lib = inputs.nixpkgs.lib;

  configPath = "${inputs.local-config}/config.nix";
  config =
    if builtins.pathExists configPath
    then import configPath
    else { };

  system = config.system or "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config = import ./nixpkgs-config.nix;
  };

  _toolchainDir = ../toolchains;
  _rawFiles = builtins.attrNames (
    lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix") (
      builtins.readDir _toolchainDir
    )
  );
  _tcIndex = lib.listToAttrs (
    map (
      f:
      let
        name = lib.removeSuffix ".nix" f;
      in
      {
        inherit name;
        value = import (_toolchainDir + "/${f}") { inherit lib pkgs; };
      }
    ) _rawFiles
  );
  _allTCs = builtins.attrValues _tcIndex;

  domainsScan = import ./domains/scan.nix {
    inherit lib;
    domainsPath = ../domains;
  };
  domainsModule = import ./domains/module.nix {
    inherit (import ./domains/activation.nix) mkDomainActivation;
  };
  domainsLib = domainsScan // domainsModule;

  _toolchains = config.toolchains or "*";
  _bareNames = builtins.attrNames _tcIndex;
in

{
  inherit _tcIndex _allTCs;

  cfg = {
    inherit system;
    hostname = config.hostname or "nixos";
    username = config.username or "user";
    theme = config.theme or "monochrome";
    password = config.password or "!";
    monitors = config.monitors or { };
    db = config.db or { };
    profiles = config.profiles or [ "base" ];
    toolchains = _toolchains;
    repoPath = config.repoPath or "proj/angst";
    extraNixos = config.nixos or { };
    extraHome = config.home or { };
    env = config.env or { };
    sshAgent = config.sshAgent or { };
    ssh = config.ssh or { };
    shell = config.shell or "";

    scan = {
      domains = domainsLib;
      themes = themesLib;
      allToolchainPackages = lib.unique (lib.concatMap (t: t.home.packages or [ ]) _allTCs);
      treesitter = import ./treesitter.nix {
        inherit lib pkgs;
        grammars = lib.unique (lib.concatMap (t: t.toolchains.treesitterGrammars or [ ]) _allTCs);
      };
    };

    toolchainModules =
      if _toolchains == "*" then
        _allTCs
      else if builtins.isList _toolchains then
        let
          unknown = builtins.filter (n: !builtins.elem n _bareNames) _toolchains;
        in
        if unknown != [ ] then
          throw "Unknown toolchains: ${builtins.concatStringsSep ", " unknown}. Valid: ${builtins.concatStringsSep ", " _bareNames}"
        else
          map (n: _tcIndex.${n}) _toolchains
      else
        throw "toolchains must be \"*\" or a list";
  };
}
```

The key change: instead of `builtins.getEnv "PWD" + "/local/config.nix"`, it reads `${inputs.local-config}/config.nix`. When `local/config.nix` doesn't exist (fresh checkout, CI), it falls back to `{ }` — same semantics as before, just pure.

### 3. Fix hardware.nix path

`lib/build/mkNixos.nix` currently uses `${toString self}/local/hardware.nix`. In pure evaluation, `self` points to the `git ls-files` copy, which excludes `local/` (gitignored). Switch to `${inputs.local-config}/hardware.nix`:

```nix
  hardwarePath =
    let
      p = "${inputs.local-config}/hardware.nix";
    in
    if builtins.pathExists p then p else null;
```

The function already receives `inputs` as a parameter — no signature change needed.

### 4. Remove --impure from justfile

Drop `--impure` from every command:

```justfile
password:
    #!/usr/bin/env bash
    read -s -p "Enter password: " pass; echo; \
    read -s -p "Confirm password: " pass2; echo; \
    if [ "$pass" != "$pass2" ]; then echo "Passwords don't match"; exit 1; fi; \
    hash=$(echo "$pass" | openssl passwd -6 -stdin); \
    grep -q '^  password = ' local/config.nix && sed -i 's|^  password = ".*";$|  password = "'"$hash"'";|' local/config.nix || sed -i '/^  toolchains = /a\  password = "'"$hash"'";' local/config.nix

disko:
    sudo nix run github:nix-community/disko -- --mode disko local/disk.nix

hardware:
    nixos-generate-config --show-hardware-config > local/hardware.nix

bootstrap: disko hardware
    @echo "Now write local/config.nix, run 'just password', then 'just build'"

build:
    nix build .#nixosConfigurations.current

switch:
    sudo nixos-rebuild switch --flake .#current

hm:
    nix build .#homeConfigurations.current.activationPackage

hm-switch:
    nix build .#homeConfigurations.current.activationPackage && ./result/activate

analyze:
    python3 -m scripts.analyze_flake --output analysis.md

check:
    nix flake check

dev:
    nix develop

vm:
    @nix shell ./tools/vm#wrapped -c vm start

vm-ssh:
    @nix shell ./tools/vm#wrapped -c vm ssh --auto-start
```

### 5. Remove --impure from scripts/angst.sh

**`repo_root_default`** no longer needs to scan for `local/config.nix`:

```bash
repo_root_default() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}
```

**`config_val`** can read the config file directly instead of `nix eval --impure`:

```bash
config_val() {
    local repo="$1" key="$2"
    nix eval --file "$repo/local/config.nix" --raw --apply "x: x.$key" 2>/dev/null || true
}
```

No `--impure` needed here — `nix eval --file` imports a file directly and doesn't require pure mode.

**All `nix eval --impure` calls** in `render_cmd` drop `--impure`:

```bash
json_data=$(nix eval "$repo_root#lib.renderDomainOutputsFor" \
    --apply "f: builtins.toJSON (map (o: { path = o.path; text = o.text; }) (f \"$theme_name\"))" --raw)
```

The flake evaluates purely since config is a `path:` input.

**`passwd_cmd`** stays at `$repo_root/local/config.nix` — no path change needed.

**`watch_cmd`** watches `$repo_root/local` (unchanged).

### 6. Remove --impure from modules/home/domain.nix

The activation script's `nix eval` call loses `--impure`:

```bash
JSON_DATA=$(cd "$CFG_SRC" && nix eval \
  "$CFG_SRC#lib.renderDomainOutputsFor" \
  --apply "f: builtins.toJSON (map (o: { path = o.path; text = o.text; }) (f \"${config.theme}\"))" \
  --raw 2>/dev/null) || true
```

No config path threading needed — the config is baked into the flake via the `path:` input. Whether the activation runs on bare metal or inside a VM (where the flake is mounted from the host at `/host/...`), `nix eval` on the flake resolves `path:./local` relative to the flake source on the host filesystem, which has `local/config.nix`.

### 7. Update tools/vm/

**`tools/vm/flake.nix`** — the bash wrappers (`vm-run-script`, `res-script`) read config values via `nix eval --impure`. Replace with `nix eval --file` (no `--impure` needed for file imports):

Replace patterns like:
```bash
TARGET_HOST="$(nix eval --impure --expr "(import $FLAKE_DIR/local/config.nix).hostname" --raw 2>/dev/null)"
```
With:
```bash
TARGET_HOST="$(nix eval --file "$FLAKE_DIR/local/config.nix" --raw --apply "x: x.hostname" 2>/dev/null)"
```

Do the same for `username`, `theme`, and `password` reads in `res-script`.

Remove `--impure` from the `res-script` build command:
```bash
nix build ".#nixosConfigurations.current.config.system.build.vm" --refresh --no-write-lock-file
```

**`tools/vm/crates/vm-cli/src/runner/vm.rs`** — `ensure_vm_profile()` reads config via `nix eval --impure --expr`. Replace with `nix eval --file`:

```rust
let output = std::process::Command::new("nix")
    .args([
        "eval",
        "--file",
        &format!("{repo}/local/config.nix"),
        "--raw",
        "--apply",
        "x: builtins.elem \"vm\" (x.profiles or [])",
    ])
    .output()
    .map_err(|e| format!("Failed to check VM profile: {e}"))?;
```

The `start()` function's `nix build --impure` becomes:
```rust
cmd.args([
    "build",
    "--refresh",
    "--no-write-lock-file",
    &format!(".#nixosConfigurations.current.config.system.build.vm"),
])
```

Error messages referencing `local/config.nix` stay the same — the file is still at that path.

### 8. Update CI workflows

**`.github/workflows/checks.yml`** — remove `--impure` from all `nix build` steps:

```yaml
- run: nix build '.#checks.x86_64-linux.lint-themes' --no-link --print-build-logs
```

The `cp local/config.nix.example local/config.nix` step stays: it creates a valid config so CI evaluates with real defaults instead of falling back to `{ }`.

**`.github/workflows/nvim-tests.yml`** — same treatment.

### 9. Minor cleanups

**`checks/password.nix`** — the skip message says "no local/config.nix". It's still accurate (the file might not exist), so no change needed.

**`scripts/seed-angst-repo.sh`** — backs up and restores `local/config.nix` during repo refreshes. This logic remains valid since the file is still at `local/config.nix`. No change needed.

## Summary of changes

| File | Change |
|---|---|
| `flake.nix` | Add `inputs.local-config = { url = "path:./local"; flake = false; }` |
| `lib/read-config.nix` | Replace `builtins.getEnv "PWD" + "/local/config.nix"` with `"${inputs.local-config}/config.nix"` |
| `lib/build/mkNixos.nix` | Change hardwarePath to `${inputs.local-config}/hardware.nix` |
| `justfile` | Drop `--impure` from all commands |
| `scripts/angst.sh` | Drop `--impure` from `nix eval` calls; simplify `repo_root_default` |
| `modules/home/domain.nix` | Drop `--impure` from activation `nix eval` call |
| `tools/vm/flake.nix` | Replace `nix eval --impure --expr` with `nix eval --file`; drop `--impure` from build |
| `tools/vm/crates/vm-cli/src/runner/vm.rs` | Replace `nix eval --impure --expr` with `--file`; drop `--impure` from `start()` build; update error strings |
| `.github/workflows/checks.yml` | Drop `--impure` from all `nix build` steps |
| `.github/workflows/nvim-tests.yml` | Drop `--impure` from `nix build` steps |

## What you gain

- **Pure evaluation** — no `--impure` anywhere. Every command is a plain `nix build`, `nix flake check`, or `nixos-rebuild switch`.
- **Same config file, same location** — `local/config.nix` stays where it is, gitignored, with no new directories or env vars.
- **Better eval caching** — the flake hash is deterministic; `nixos-rebuild list-generations` and `--rollback` work reliably.
- **Zero ceremony** — no `--override-input`, no `ANGST_CONFIG`, no config path threading. The config is just a file in a directory, picked up automatically.

## Caveats

- **Lock file churn in multi-contributor repos**: `path:` inputs hash the directory contents into `flake.lock`. If different developers have different `local/config.nix` files, the lock file will differ. This is cosmetic for a single-user repo, but if you ever share the repo, add `flake.lock` to `.gitignore` for the `local-config` input section, or use a separate CI config that doesn't touch the lock.

- **Config must live inside the flake repo**: `path:./local` resolves relative to the flake root. If you later want per-machine configs outside the repo, a shell wrapper that symlinks `~/angst-config/$(hostname)/default.nix` → `local/config.nix` before building handles it without touching the flake.

## Optional future steps

- **sops-nix / agenix** — encrypt secrets (passwords, API keys) directly in `local/config.nix` so it can be committed without exposure.
- **Multi-machine with symlink wrapper** — a `build.sh` that detects the hostname and symlinks the right config before invoking nix, if you ever need external config dirs.
