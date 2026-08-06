# Pure Flake Migration

This guide describes how to convert angst from an impure flake (`builtins.getEnv "PWD"` pattern) to a pure flake, while keeping per-machine config files separate from the flake source (not tracked by git).

## Concept

```
angst/                       # flake repo (pure, tracked by git)
├── flake.nix                # declares inputs.config with a fallback
├── hosts/
│   └── default.nix          # fallback empty config { }
├── lib/read-config.nix      # renamed to lib/load-config.nix
│                            # reads from inputs.config, not builtins.getEnv
└── ...

~/angst-config/              # per-machine config (NOT tracked by git)
├── pc/
│   └── default.nix          # { system="x86_64-linux"; hostname="pc"; ... }
├── laptop/
│   └── default.nix          # { system="x86_64-linux"; hostname="laptop"; ... }
└── vps/
    └── default.nix          # { system="aarch64-linux"; hostname="vps"; ... }
```

Build commands pass the config directory at invocation time:

```bash
# NixOS machines
sudo nixos-rebuild switch --flake .#current --override-input config ~/angst-config/pc

# Non-NixOS (home-manager only)  
home-manager switch --flake .#current --override-input config ~/angst-config/laptop
```

The override tells the flake "use this directory as the `config` input instead of the fallback." The flake itself never calls `builtins.getEnv` — config arrives as a declared flake input, keeping evaluation pure.

## Step-by-step

### 1. Create the fallback config

```bash
mkdir -p hosts
```

**`hosts/default.nix`** — an empty config, so the flake can evaluate without an override:

```nix
{ }
```

This directory lives inside the flake repo and is tracked by git. It's the "no machine" default used only for dev shells and CI.

### 2. Add config input to flake.nix

Add a `config` input pointing at the fallback:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    config = {
      url = "path:./hosts/default";
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
  # ...
}
```

`flake = false` means Nix won't try to interpret it as a flake — it just exposes the directory as a path the outputs function can import.

### 3. Rewrite lib/read-config.nix → lib/load-config.nix

Replace the impure `builtins.getEnv "PWD"` with reading from `inputs.config`:

**`lib/load-config.nix`:**

```nix
{
  inputs,
  themesLib,
}:

let
  lib = inputs.nixpkgs.lib;

  configPath = "${inputs.config}/default.nix";
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

The key change: instead of `builtins.getEnv "PWD" + "/local/config.nix"`, it reads `${inputs.config}/default.nix`. That's it — one line changes.

### 4. Update flake.nix output

Change the import path and rename the variable:

```nix
outputs =
  { self, nixpkgs, ... }@inputs:
  let
    themesLib = import ./themes/default.nix { lib = inputs.nixpkgs.lib; };
    pure = import ./lib/load-config.nix { inherit inputs themesLib; };
    inherit (pure) cfg;
    # ...
  in
  import ./lib/flake/outputs.nix {
    inherit self inputs cfg profiles;
  };
```

### 5. Fix hardware.nix path in mkNixos.nix

Currently hardware.nix is found via `${toString self}/local/hardware.nix` which relies on `local/` being in the flake source. Since `local/` is gitignored, this path won't exist in pure evaluations (the flake source is determined by `git ls-files`).

Option: the per-machine config dir can hold `hardware.nix` alongside `default.nix`. Pass it through the config:

Replace in `lib/build/mkNixos.nix`:

```nix
  hardwarePath =
    let
      p = "${toString self}/local/hardware.nix";
    in
    if builtins.pathExists p then p else null;
```

With:

```nix
  hardwarePath =
    let
      p = "${inputs.config}/hardware.nix";
    in
    if builtins.pathExists p then p else null;
```

Add `inputs` to the mkNixos function parameters.

### 6. Move local/config.nix out of the flake repo

For each machine, create a config directory outside the angst repo:

```bash
mkdir -p ~/angst-config/pc
```

Copy your existing `local/config.nix` into `~/angst-config/pc/default.nix` and strip any secrets you'd rather handle differently later.

The `local/` directory (and especially `local/config.nix`) can be deleted from the flake repo, or kept as `.gitignore`'d convenience — the pure flake won't read from it anymore.

### 7. Remove --impure from all invocations

Update `justfile`:

```justfile
config_arg := env_var_or_default("ANGST_CONFIG", "hosts/default")

password:
    #!/usr/bin/env bash
    config_dir="${ANGST_CONFIG:-$HOME/angst-config/pc}"
    config_file="$config_dir/default.nix"
    if [ ! -f "$config_file" ]; then
        echo "Error: $config_file not found. Set ANGST_CONFIG or create it." >&2
        exit 1
    fi
    read -s -p "Enter password: " pass; echo; \
    read -s -p "Confirm password: " pass2; echo; \
    if [ "$pass" != "$pass2" ]; then echo "Passwords don't match"; exit 1; fi; \
    hash=$(echo "$pass" | openssl passwd -6 -stdin); \
    grep -q '^  password = ' "$config_file" && sed -i 's|^  password = ".*";$|  password = "'"$hash"'";|' "$config_file" || sed -i '/^  toolchains = /a\  password = "'"$hash"'";' "$config_file"

disko:
    sudo nix run github:nix-community/disko -- --mode disko ~/angst-config/pc/disk.nix

hardware:
    nixos-generate-config --show-hardware-config > ~/angst-config/pc/hardware.nix

bootstrap: disko hardware
    @echo "Now write ~/angst-config/pc/default.nix, run 'just password', then 'just build'"

build:
    nix build .#nixosConfigurations.current --override-input config {{config_arg}}

switch:
    sudo nixos-rebuild switch --flake .#current --override-input config {{config_arg}}

hm:
    nix build .#homeConfigurations.current.activationPackage --override-input config {{config_arg}}

hm-switch:
    nix build .#homeConfigurations.current.activationPackage --override-input config {{config_arg}} && ./result/activate

analyze:
    python3 -m scripts.analyze_flake --output analysis.md

check:
    nix flake check --override-input config {{config_arg}}

dev:
    nix develop --override-input config {{config_arg}}

vm:
    @nix shell ./tools/vm#wrapped -c vm start

vm-ssh:
    @nix shell ./tools/vm#wrapped -c vm ssh --auto-start
```

Set `ANGST_CONFIG` in your shell profile per machine:

```bash
# ~/.bashrc or ~/.config/nushell/env.nu
export ANGST_CONFIG="$HOME/angst-config/pc"
```

### 8. Update scripts/angst.sh

Replace `repo_root_default()` — instead of searching for `local/config.nix`, have it look for a config path:

```bash
repo_root_default() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

config_dir() {
    local dir="${ANGST_CONFIG:-$HOME/angst-config/default}"
    if [ ! -d "$dir" ]; then
        echo "Error: config directory '$dir' not found. Set ANGST_CONFIG." >&2
        exit 1
    fi
    printf '%s\n' "$dir"
}

config_file() {
    printf '%s/default.nix' "$(config_dir)"
}
```

Replace all `nix eval --impure "$repo_root#..."` with:

```bash
local repo_root
repo_root="$(repo_root_default)"
local cfg_dir
cfg_dir="$(config_dir)"
nix eval "$repo_root#lib.renderDomainOutputsFor" \
    --override-input config "$cfg_dir" \
    --apply "..."
```

Remove the `--impure` flag. Update the `passwd_cmd` function to write to `$(config_file)` instead of `$repo_root/local/config.nix`. Update `watch_cmd` to watch `$cfg_dir` instead of `$repo_root/local`.

### 9. Update modules/home/domain.nix

Find the `nix eval --impure` calls and replace with `--override-input config`:

Replace:
```bash
nix eval --impure "${self}#..."  # or similar
```

With:
```bash
nix eval "${self}#lib.renderDomainOutputsFor" \
    --override-input config "${configSource}" \
    --apply "..."
```

The config source path needs to be threaded through as a module parameter or derived from `flakeSelf` (since the activation script runs on the host and the config dir may not be accessible at the same path). This is the trickiest part. Two approaches:

**A) Store config path in a file:** During NixOS/home-manager build, write the config dir path to a known location in the user's home. The activation script reads it.

**B) Pre-render at build time:** Instead of rendering in the activation script, render at build time and symlink the results. The activation script just seeds the repo and symlinks. This is arguably cleaner but requires restructuring the render pipeline.

**C) Thread `configSource` via extraSpecialArgs:** Pass the config input path through `extraSpecialArgs` down to the home module.

Option C is simplest — add to both `mkHome.nix` and `mkNixos.nix`:

```nix
extraSpecialArgs = {
  # ... existing ...
  configSource = "${inputs.config}";
};
```

Then in the home activation script (`modules/home/domain.nix`), use `config.configSource` instead of the impure `self`-based path.

### 10. Update tools/ sub-flakes

The `tools/vm/flake.nix` and `tools/shell/flake.nix` also have `nix eval --impure` calls. These need the config override passed through. Since they're called by the root flake's apps, thread the config override as a parameter or have them read `ANGST_CONFIG` from the environment at runtime (which is fine — it's not flake evaluation, it's a runtime script).

## Summary of changes

| File | Change |
|---|---|
| `hosts/default.nix` | **New** — empty fallback config |
| `flake.nix` | Add `inputs.config`, rename `import ./lib/read-config.nix` → `./lib/load-config.nix` |
| `lib/read-config.nix` | **Rename to `lib/load-config.nix`**, replace `builtins.getEnv "PWD"` with `${inputs.config}/default.nix` |
| `lib/build/mkNixos.nix` | Change hardwarePath to `${inputs.config}/hardware.nix`, accept `inputs` param |
| `lib/flake/outputs.nix` | Add `--override-input config` to check app, ssh app |
| `justfile` | Add `config_arg`, replace all `--impure` with `--override-input config {{config_arg}}` |
| `scripts/angst.sh` | Replace `local/config.nix` scanning with `$ANGST_CONFIG`/`--override-input`, remove `--impure` |
| `modules/home/domain.nix` | Thread `configSource` via `extraSpecialArgs`, replace `--impure` eval calls |
| `tools/vm/` and `tools/shell/` | Replace `--impure` calls or pass config override |

Files you move/delete:

| Action | File |
|---|---|
| Move | `local/config.nix` → `~/angst-config/<host>/default.nix` per machine |
| Move | `local/hardware.nix` → `~/angst-config/<host>/hardware.nix` per machine |
| Keep | `local/` directory (gitignored, harmless) or delete |
| Keep | `local/config.nix.example` if you want to keep a template |

## Per-machine setup

After migration, each machine needs:

```bash
# 1. Clone the flake
git clone <angst-repo> ~/proj/angst

# 2. Create your machine config
mkdir -p ~/angst-config/$(hostname)
cp ~/proj/angst/local/config.nix ~/angst-config/$(hostname)/default.nix
# Edit as needed

# 3. Set ANGST_CONFIG
echo 'export ANGST_CONFIG="$HOME/angst-config/'"$(hostname)"'"' >> ~/.bashrc

# 4. Build
cd ~/proj/angst
just switch   # NixOS
just hm-switch   # home-manager only
```

## What you gain

- **Pure evaluation** — no `--impure` anywhere. The flake's output depends only on its declared inputs.
- **Better eval guardrails** — if a machine config is missing, you get a clear error instead of silent defaults.
- **Generation management** — `nixos-rebuild list-generations` and `--rollback` work reliably since the flake hash is deterministic.
- **Config and flake evolve independently** — change the flake pipeline without touching machine config, change machine config without touching the flake.
- **No git-committed per-machine config** — each machine's config lives in `~/angst-config/<host>/`, synced however you want (rsync, Syncthing, USB stick, or not at all).

## Optional future steps

- **sops-nix / agenix** — encrypt secrets (passwords, API keys) in the config files so they can be committed without exposure.
- **Multiple configs per machine** — one config file for the "identity" (hostname, username, theme, profiles) and another for secrets, passed as two separate inputs.
- **deploy-rs / colmena** — if you want remote deployment to multiple machines from a central place.
