# Introduction

The idea is to refac my whole nix repo, there are several flaws descripted on `analysis.md` that are apparent in build time and usage of the system.

# Use cases

There are various use cases that i want to cover that were made diffucult by the current architecture. I've been running this system on various hosts ranging from virtual machine, NixOS system and regular linux distro which have only access to nix package manager, and each host have its particularities like only using the system via ssh, only needing some specific toolchains for a debian server or running only home-manager in a regular linux distro.

# Problems

- There's no differentiation between home-manager related packages and NixOS configurations, they are all bundled together meaning i have little control how to run the system under different conditions.
- I'm forced to create a new host for every machine that ill run the system, even though i cant possibly predict if i will need the system to work in a completely different host. this obligates me to know before hand or to spend some time into creating a unique host if i ever want to use the system
- Since flake is based on git, it inherent all of the systems state such as user, themes and any other host specific configurations. Since i might use each host differently, i must be able to keep the system requirements outside git, allowing me to manage the way and reason im going to use it without have conflicts with new system versions or changes.
- There are several bottlenecks listed in ´analysis.md´ that makes the build time largely bigger than i must be.

! dont edit the text above

______________________________________________________________________

## Plan

### Core idea

`local/config.nix` (gitignored) is the **source of truth** for machine identity. **Profiles** (under `profiles/`) are reusable bundles of co-dependent configs — e.g., `desktop` enables i3 + bar + launcher + graphical capabilities as a unit. `lib/resolve.nix` reads config, applies env var overrides, and calls existing scan functions once — no duplicate scanning, no I/O in builders.

Existing domain/theme/capability/toolchain structure is **untouched** — only the wiring around them changes.

______________________________________________________________________

### Phase 1 — Core

All new files created; existing code still works alongside them.

#### `lib/resolve.nix` — single entry point

Reads `local/config.nix` (or `$ANGST_CONFIG` env var override), applies `ANGST_HOST`/`ANGST_USERNAME`/`ANGST_THEME`/`ANGST_PASSWORD` overrides, resolves toolchains (unset/`"*"` → all, list → specific), calls existing scan functions once, and derives `repoPath` from `self.sourceInfo.outPath`:

> Env var overrides require `--impure` at eval time (e.g., `nix build --impure .#...`). Pure evaluation reads only `local/config.nix`.

The implementation guards against a missing config file and auto-derives `repoPath` from `self.sourceInfo.outPath` (with fallback):

```nix
# lib/resolve.nix
{ inputs, self }:

let
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
  lib = pkgs.lib;

  # ---- config loading (with helpful error) ----
  configPath = if builtins.pathExists ../local/config.nix
               then ../local/config.nix
               else builtins.throw "Create local/config.nix (see local/config.nix.example)";
  config = import configPath;

  # ---- repoPath: derive from flake root path (self.sourceInfo.outPath) ----
  repoPath = let
    flakePath = builtins.toString self.sourceInfo.outPath;
    home = builtins.getEnv "HOME";
  in
  if flakePath != "" && home != ""
  then builtins.substring (builtins.stringLength home + 1) (-1) flakePath
  else "proj/angst";

  # ---- env overrides (require --impure) ----
  envHost     = builtins.getEnv "ANGST_HOST";
  envUsername = builtins.getEnv "ANGST_USERNAME";
  envTheme    = builtins.getEnv "ANGST_THEME";
  envPassword = builtins.getEnv "ANGST_PASSWORD";
in
{
  cfg = {
    system     = config.system or "x86_64-linux";
    hostname   = if envHost     != "" then envHost     else config.hostname;
    username   = if envUsername != "" then envUsername else config.username;
    theme      = if envTheme    != "" then envTheme    else config.theme;
    password   = if envPassword != "" then envPassword else config.password;
    monitors   = config.monitors or {};
    profiles   = config.profiles or [ "base" ];
    toolchains = config.toolchains or "*";
    extraNixos = config.nixos or {};
    extraHome  = config.home or {};
    inherit repoPath;

    # resolved from scan (evaluated once here, not by builders)
    scan = let
      domainsLib = import ../lib/domains/default.nix { inherit lib; domainsPath = ../domains; };
      themesLib  = import ../themes/default.nix { inherit lib; };
      toolchainDir = ../toolchains;
      toolchainFiles = builtins.attrNames (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix")
          (builtins.readDir toolchainDir)
      );
      evaluatedToolchains = map (f: import (toolchainDir + "/${f}") { inherit lib pkgs; }) toolchainFiles;
      allGrammars = lib.unique (lib.concatMap (t: t.toolchains.treesitterGrammars or []) evaluatedToolchains);
    in {
      domains = domainsLib;
      themes = themesLib;
      allToolchainPackages = lib.unique (lib.concatMap (t: t.home.packages or []) evaluatedToolchains);
      treesitter = import ../lib/treesitter.nix { inherit lib pkgs; grammars = allGrammars; };
      capabilities = import ../capabilities { };
    };

    # toolchain modules — resolved once based on config.toolchains
    toolchainModules =
      let
        resolveOne = name: import (../toolchains + "/${name}.nix") { inherit lib pkgs; };
        allNames = builtins.attrNames (
          lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix")
            (builtins.readDir ../toolchains)
        );
        bareNames = map (lib.removeSuffix ".nix") allNames;
      in
      if config.toolchains == "*" then map resolveOne bareNames
      else if builtins.isList config.toolchains
      then let
        unknown = builtins.filter (n: !builtins.elem n bareNames) config.toolchains;
      in if unknown != []
        then builtins.throw "Unknown toolchains: ${builtins.concatStringsSep ", " unknown}. Valid: ${builtins.concatStringsSep ", " bareNames}"
        else map resolveOne config.toolchains
      else builtins.throw "toolchains must be \"*\" or a list";
  };
}
```

All builders receive the same `cfg` — no duplicate scanning, no env re-parsing.

**No `lib/scan/` directory** — the scan is just calling existing modules. The duplication was that they were called in 7 places; now they're called once in `resolve.nix`.

**Files to create:** `lib/resolve.nix`

#### Profiles (`profiles/`)

Each profile returns `{ hm, nixos }` — two lists of NixOS/HM modules (paths or inline attrsets).

Domain custom modules (e.g., `domains/wm/i3/module.nix`) depend on `config.domains.wm.i3.enable` which is **defined by `mkDomainModule` from the scan system**, not by the module file itself. So profiles can't list domain `module.nix` paths directly. Instead, profile `hm` lists **inline enable modules** — simple attrsets that set `enable = true`. The builders still import all domain modules via `mkDomainModule` from `cfg.scan.domains`; profiles just decide which ones are active.

```nix
# profiles/desktop.nix
{
  hm = [
    ({ ... }: { domains.wm.i3.enable = true; })
    ({ ... }: { domains.bar.i3status.enable = true; })
    ({ ... }: { domains.launcher.rofi.enable = true; })
    ({ ... }: { domains.terminal.ghostty.enable = true; })
  ];
  nixos = [
    ../../capabilities/graphical.nix
    ../../capabilities/audio.nix
    ../../capabilities/clipboard.nix
  ];
}
```

> **Safety note:** The inline enable attrsets silently no-op if the domain option path changes (e.g., a rename of `i3` to `i3wm`). Consider adding a `lib/mkDomainEnable.nix` helper that validates domain names against `cfg.scan.domains.homeEntries` at eval time — e.g., `lib.mkDomainEnable "wm.i3"` which looks up the domain entry and returns the enable attrset, or throws with an available-list error if not found. This is optional but recommended for early failure.

- Later profiles in the list override earlier ones (NixOS/HM module import order)
- On **NixOS**: `mkHost.nix` applies both `hm` + `nixos` parts
- On **non-NixOS**: `mkHome.nix` applies only the `hm` part
- No conditionals, no `mkIf` tricks, no `hosts/` directory fallback

| Profile | `hm` modules | `nixos` modules |
|---|---|---|
| `base` | nushell, starship, zellij, nvim, yazi, lazygit | network, git, search, monitoring, container capabilities |
| `desktop` | i3, i3status, rofi, ghostty, x11 | graphical, audio, clipboard capabilities |
| `development` | opencode, cursor-cli, sqlit, posting | (none) |
| `server` | (none) | ssh capability |
| `vm` | (none) | `lib/virtualisation/vm-profile.nix` (virtio/9p/SPICE, qemu mounts, VM detected keys) |

**Profile resolution** (`lib/profiles.nix`):

```nix
resolve = names:
  let
    validNames = builtins.attrNames profileMap;
    unknown = builtins.filter (n: !builtins.elem n validNames) names;
  in
  if unknown != []
  then builtins.throw "Unknown profiles: ${builtins.concatStringsSep ", " unknown}. Valid: ${builtins.concatStringsSep ", " validNames}"
  else {
    hm  = lib.concatMap (n: profileMap.${n}.hm)  names;
    nixos = lib.concatMap (n: profileMap.${n}.nixos) names;
  };
```

No toolchain imports in profiles — toolchain selection is driven by `config.nix.toolchains`. Same validation pattern applies to toolchain names in `resolve.nix`.

**Files to create:** `profiles/base.nix`, `profiles/desktop.nix`, `profiles/development.nix`, `profiles/server.nix`, `profiles/vm.nix`, `lib/profiles.nix`

#### `lib/build/mkHome.nix` — pure builder

Imports the scan's `mkDomainModule` for all home entries (so domain options exist), plus infrastructure modules (`lib/home`, theme module, i3Fragments). Profile `hm` modules just enable the subset of domains the user wants.

```nix
{ inputs, cfg, hmModules, vmTool, shellTool, angstTool, themeOverride ? null }:

let
  pkgs = import inputs.nixpkgs { system = cfg.system; config.allowUnfree = true; };
  lib = pkgs.lib;

  effectiveTheme = if themeOverride != null then themeOverride else cfg.theme;
  userCfg = { username = cfg.username; homeDirectory = "/home/${cfg.username}"; };

  # all domain modules imported (enable defaults to false)
  appHomeModules = map cfg.scan.domains.mkDomainModule cfg.scan.domains.homeEntries;

  themeModule = import ../home/themeModule.nix {
    inherit lib; themesLib = cfg.scan.themes; hostTheme = effectiveTheme;
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = pkgs;

  extraSpecialArgs = {
    inherit (cfg) hostname monitors repoPath;
    inherit (cfg.scan) themes;
    userConfig = userCfg;
    theme = effectiveTheme;
  };

  modules =
    [ ../../lib/home ]
    ++ [ themeModule ../../lib/home/i3Fragments.nix ]
    ++ appHomeModules               # all domain modules from scan
    ++ hmModules                    # profile enable modules
    ++ cfg.toolchainModules
    ++ [({ ... }: { home.packages = [ vmTool shellTool angstTool ]; })]
    ++ (if cfg.extraHome != {} then [ cfg.extraHome ] else []);
}
```

**Files to modify:** `lib/build/mkHome.nix`

#### `lib/build/mkHost.nix` — pure builder

Same pattern as `mkHome.nix`: imports all domain NixOS modules from scan, then profile nixos modules on top. `hardware.nix` path is derived from `self.sourceInfo.outPath + "/local/hardware.nix"` (relative path avoided for robustness). Must pass `userConfig`/`repoPath` in `specialArgs` for `vm-variant.nix`, `host-mount.nix`, etc.

The NixOS-embedded HM config also imports domain home modules (via `mkDomainModule`), so domain enable options are available inside HM.

```nix
{ inputs, self, cfg, hmModules, nixosModules, themeOverride ? null }:

let
  pkgs = import inputs.nixpkgs { system = cfg.system; config.allowUnfree = true; };
  lib = pkgs.lib;

  effectiveTheme = if themeOverride != null then themeOverride else cfg.theme;
  userCfg = { username = cfg.username; homeDirectory = "/home/${cfg.username}"; };

  appNixosModules = map cfg.scan.domains.mkNixosDomainModule cfg.scan.domains.nixosEntries;
  appHomeModules  = map cfg.scan.domains.mkDomainModule cfg.scan.domains.homeEntries;

  themeModule = import ../home/themeModule.nix {
    inherit lib; themesLib = cfg.scan.themes; hostTheme = effectiveTheme;
  };
in
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = {
    inherit (cfg) hostname monitors repoPath;
    inherit (cfg.scan) themes;
    userConfig = userCfg;
    theme = effectiveTheme;
  };

  modules =
    [ { nixpkgs.hostPlatform = cfg.system; } ]
    ++ nixosModules
    ++ appNixosModules
    ++ [ ../../lib/nixos ]
    ++ (if builtins.pathExists (builtins.toString self.sourceInfo.outPath + "/local/hardware.nix") then [ (import (builtins.toString self.sourceInfo.outPath + "/local/hardware.nix")) ] else [])
    ++ (if cfg.extraNixos != {} then [ cfg.extraNixos ] else [])
    ++ [
      ({ lib, ... }: {
        users.users.${cfg.username}.hashedPassword = lib.mkDefault cfg.password;
      })

      inputs.home-manager.nixosModules.home-manager {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "hm-backup";

          extraSpecialArgs = {
            inherit (cfg) hostname monitors repoPath;
            inherit (cfg.scan) themes;
            userConfig = userCfg;
            theme = effectiveTheme;
          };

          users.${cfg.username} = {
            imports =
              [ ../../lib/home ]
              ++ [ themeModule ../../lib/home/i3Fragments.nix ]
              ++ appHomeModules     # domain modules (so enable options exist)
              ++ hmModules          # profile enable modules
              ++ cfg.toolchainModules;
          };
        };
      }

      ({ config, lib, ... }: {
        systemd.services."home-manager-${cfg.username}".before =
          lib.mkIf (!config.angst.isQemuVm) [
            "getty@.service" "serial-getty@.service"
          ];
      })
    ];
}
```

> **Note:** `lib/nixos/default.nix` currently reads `ANGST_PASSWORD` from env (`builtins.getEnv "ANGST_PASSWORD"`). This must be changed — password is now set directly by the `{ users.users.${cfg.username}.hashedPassword = lib.mkDefault cfg.password; }` line in `mkHost.nix`. Remove the env-read from `lib/nixos/default.nix` so it becomes a pure module using only its function arguments.

**Files to modify:** `lib/build/mkHost.nix`, `lib/nixos/default.nix` (remove `ANGST_PASSWORD` env read)

#### `lib/outputs.nix` — single output file

Replaces `lib/flake/default.nix` (397 LOC, fan-out 12). Checks are split into `lib/checks/default.nix` for readability; shared inline tools (`vmRunShim`, `resWrapper`, `angstCli`, dev shell packages, `fullDevPackages`, `shellDevHook`) can live in `lib/shared/default.nix` to keep `outputs.nix` under 250 LOC. `outputs.nix` imports both and merges the result:

```nix
{ self, inputs, cfg, profiles }:

let
  pkgs = import inputs.nixpkgs { system = cfg.system; config.allowUnfree = true; };
  lib = pkgs.lib;

  mkHome = import ./build/mkHome.nix;
  mkHost = import ./build/mkHost.nix;

  hmModules     = profiles.hm;
  nixosModules  = profiles.nixos;

  # local tool outputs (vm-cli, shell-cli)
  vmOutputs    = inputs.vm.mkOutputs self;
  shellOutputs = inputs.shell.mkOutputs self;

  vmTool    = vmOutputs.packages.${cfg.system}.default;
  shellTool = shellOutputs.packages.${cfg.system}.default;

  # tools built here (previously in shared.nix)
  angstCli = pkgs.writeShellApplication {
    name = "angst";
    runtimeInputs = with pkgs; [ coreutils findutils git nix watchexec jq mkpasswd ];
    text = builtins.readFile ./scripts/angst.sh;
  };

  vmRunShim = pkgs.writeShellScriptBin "vm-run" ''
    TARGET_HOST="${cfg.hostname}"
    KEY_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/vm/keys/$TARGET_HOST"
    KEY_FILE="$KEY_DIR/authorized_keys"
    mkdir -p "$KEY_DIR"
    TMP_KEYS="$(mktemp)"; trap 'rm -f "$TMP_KEYS"' EXIT
    ssh-add -L 2>/dev/null >> "$TMP_KEYS" || true
    for pubkey in "$HOME"/.ssh/*.pub; do
      [ -r "$pubkey" ] && cat "$pubkey" >> "$TMP_KEYS"
    done
    awk '/^(ssh-rsa|ssh-ed25519|ecdsa-sha2-|sk-ssh-|sk-ecdsa-)/ { print }' "$TMP_KEYS" | sort -u > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    [ -s "$KEY_FILE" ] || { echo "Error: no SSH public keys found" >&2; exit 1; }
    export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$PWD/$TARGET_HOST.qcow2}"
    export SHARED_DIR="$KEY_DIR"
    export QEMU_NET_OPTS="hostfwd=tcp::2222-:22"
    exec nix run "git+file://$PWD#nixosConfigurations.$TARGET_HOST.config.specialisation.vm.configuration.system.build.vm" -- "$@"
  '';

  resWrapper = pkgs.writeShellScriptBin "res" ''
    cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")" || exit 1
    exec nix run ".#res" --impure --refresh -- "$@"
  '';

  # dev shell — all toolchains always available
  allToolchainPkgs = cfg.scan.allToolchainPackages;
  treesitter = cfg.scan.treesitter;

  treesitterShellHook = ''
    mkdir -p ~/.local/share/tree-sitter
    rm -rf ~/.local/share/tree-sitter/parser ~/.local/share/tree-sitter/queries 2>/dev/null
    ln -sf ${treesitter.treesitterParsers} ~/.local/share/tree-sitter/parser
    ln -sf ${treesitter.treesitterQueries} ~/.local/share/tree-sitter/queries
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH
  '';

  shellDevHook = pkgs.writeText "shell-dev-hook" ''
    export VM_SSH_PORT=2222
    export NIX_DEFAULT_TARGET_HOST=${cfg.hostname}
    export CARGO_BUILD_TARGET_DIR="$PWD/target"
    if [ -z "$SSH_AUTH_SOCK" ]; then
      eval $(ssh-agent -s) > /dev/null
      trap "ssh-agent -k > /dev/null" EXIT
    fi
    for key in "$HOME"/.ssh/id_ed25519 "$HOME"/.ssh/id_rsa; do
      [ -f "$key" ] && ssh-add "$key" 2>/dev/null || true
    done
  '';

  fullDevPackages = with pkgs; [
    neovim git angstCli openssh qemu cargo rustc rust-analyzer
  ] ++ allToolchainPkgs ++ [
    vmOutputs.packages.${cfg.system}.wrapped
    vmOutputs.packages.${cfg.system}.vm-run
    vmOutputs.packages.${cfg.system}.res
  ];

  # rendered domain outputs (used by checks + lib export)
  renderDomainOutputsFor = hostName: themeName:
    let
      themesLib = cfg.scan.themes;
      fontsLib = import ../home/fonts.nix;
      checkHelpers = import ../checks/theme/assertions.nix { inherit lib; theme = themesLib.get themeName; inherit themeName; };
      domainRendererPaths = map (e: "${e.path}/render.nix") (
        lib.filter (e: e.hasRender or false) cfg.scan.domains.homeEntries
      );
    in lib.concatLists (map (path: import path {
      inherit lib themesLib themeName checkHelpers fontsLib;
      fontFamily = fontsLib.defaultFamily;
      monitors = cfg.monitors or {};
      homeDirectory = "/home/${cfg.username}";
    }) domainRendererPaths);

  renderDomainOutputFor = hostName: themeName: outputPath:
    let
      matches = lib.filter (output: output.path == outputPath) (renderDomainOutputsFor hostName themeName);
    in if matches == [] then builtins.throw "Unknown domain render output: ${outputPath}"
      else (builtins.head matches).text;

  # checks (extracted to lib/checks/default.nix for readability)
  mkChecks = import ./checks/default.nix {
    inherit self inputs cfg profiles pkgs lib renderDomainOutputsFor renderDomainOutputFor;
  };

  # used by lib export (the rest of the check logic lives in lib/checks/default.nix)
  themeLint = import ../checks/theme {
    inherit lib;
    themesLib = cfg.scan.themes;
    renderDomainOutputsFor = renderDomainOutputsFor cfg.hostname;
  };
in rec {
  homeConfigurations = {
    current = mkHome { inherit inputs cfg hmModules vmTool shellTool angstTool; };
    "${cfg.username}@${cfg.hostname}" = mkHome { inherit inputs cfg hmModules vmTool shellTool angstTool; };
  } // {
    "${cfg.username}-theme-override-test" =
      let
        overrideTheme = lib.head (lib.filter (n: n != cfg.theme) (lib.attrNames cfg.scan.themes.themes));
      in
      mkHome {
        inherit inputs cfg hmModules vmTool shellTool angstTool;
        themeOverride = overrideTheme;
      };
  };

  nixosConfigurations = {
    current = mkHost { inherit inputs self cfg hmModules nixosModules; };
    "${cfg.hostname}" = mkHost { inherit inputs self cfg hmModules nixosModules; };
  };

  packages = {
    ${cfg.system} = {
      default = homeConfigurations.current.activationPackage;
      angst   = angstCli;
      vm-cli  = vmOutputs.packages.${cfg.system}.wrapped;
      vm      = vmOutputs.packages.${cfg.system}.wrapped;
      vm-run  = vmOutputs.packages.${cfg.system}.vm-run;
      res     = vmOutputs.packages.${cfg.system}.res;
      shell   = shellTool;
    };
  };

  devShells = {
    ${cfg.system} = {
      safe = pkgs.mkShell {
        packages = with pkgs; [ neovim git ] ++ allToolchainPkgs;
        shellHook = treesitterShellHook;
      };

      dev = pkgs.mkShell {
        packages = fullDevPackages;
        shellHook = "${treesitterShellHook}\n. ${shellDevHook}";
      };

      vm = pkgs.mkShell {
        inputsFrom = [ inputs.vm.devShells.${cfg.system}.default ];
        packages = fullDevPackages;
        shellHook = "${treesitterShellHook}\n. ${shellDevHook}";
      };
    };
  };

  apps = {
    ${cfg.system} = {
      vm = {
        type = "app";
        program = "${vmOutputs.packages.${cfg.system}.wrapped}/bin/vm";
      };
      shell = {
        type = "app";
        program = "${shellTool}/bin/shell";
      };
      angst = {
        type = "app";
        program = "${angstCli}/bin/angst";
      };
      render = {
        type = "app";
        program = "${pkgs.writeShellScript "angst-render" ''exec ${angstCli}/bin/angst render "$@"''}";
      };
      watch = {
        type = "app";
        program = "${pkgs.writeShellScript "angst-watch" ''exec ${angstCli}/bin/angst watch "$@"''}";
      };
      check = {
        type = "app";
        program = "${pkgs.writeShellScript "check" ''set -euo pipefail; ${pkgs.nix}/bin/nix flake check --print-build-logs''}";
      };
      lint-themes = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-themes" ''set -euo pipefail; ${pkgs.nix}/bin/nix eval ${self}#lib.themeLint --raw''}";
      };
      lint-desktop = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-desktop" ''set -euo pipefail; ${pkgs.nix}/bin/nix build ${self}#checks.${cfg.system}.lint-desktop --no-link --print-build-logs; echo "All desktop config checks passed."''}";
      };
      lint-shell = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-shell" ''set -euo pipefail; ${pkgs.nix}/bin/nix build ${self}#checks.${cfg.system}.lint-shell --no-link --print-build-logs; echo "All shell config checks passed."''}";
      };
      analyze = {
        type = "app";
        program = "${pkgs.writeShellScript "analyze" ''exec python3 -m scripts.analyze_flake "$@"''}";
      };
      analyze-to-file = {
        type = "app";
        program = "${pkgs.writeShellScript "analyze-to-file" ''cd "$(git rev-parse --show-toplevel)" && exec python3 -m scripts.analyze_flake --output analysis.md "$@"''}";
      };
      ssh = {
        type = "app";
        program = "${pkgs.writeShellScript "angst-ssh-deploy" ''
          set -euo pipefail
          echo "==> Building & activating ${cfg.username}@${cfg.hostname}..."
          nix build ${self}#homeConfigurations.${cfg.username}@${cfg.hostname}.activationPackage --print-build-logs
          echo "==> Activating..."; ./result/activate
          echo "==> Cleaning old Nix store..."; nix-collect-garbage -d; nix store gc; echo "==> Done."
        ''}";
      };
    };
  };

  checks = mkChecks homeConfigurations;

  formatter.${cfg.system} = pkgs.nixfmt;

  lib = {
    inherit renderDomainOutputsFor renderDomainOutputFor themeLint;
  };
}
```

No `common/`, `hosts/`, `user.env`, or env re-parsing involved.

**Files to create:** `lib/outputs.nix`, `lib/checks/default.nix`

______________________________________________________________________

### Phase 2 — `local/` + `flake.nix`

#### `local/` directory

- Create `local/` directory, add to `.gitignore`
- `local/config.nix` is the **sole source of machine identity** — no fallback files:

```nix
{
  system = "x86_64-linux";
  hostname = "personal";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development"];
  toolchains = "*";  # or ["bash" "nix" "php"] for server

  # Hashed password — NOT plaintext. Generate with: mkpasswd -m sha-512
  password = "$6$CHANGE_ME_REPLACE_WITH_REAL_HASH";

  monitors.primary = {
    name = "DP-1";
    resolution = "1920x1080";
    refresh = 144;
  };

  nixos = {};  # one-off NixOS config (replaces host-specific configuration.nix)
  home = {};   # one-off HM config (replaces host-specific home.nix)
}
```

No `local/home.nix`, `local/configuration.nix`, or any other fallback file. The `nixos` and `home` attrs are the only escape hatch. Auto-merged as additional modules by the builders.

Hardware: `nixos-generate-config --show-hardware-config > local/hardware.nix` (auto-imported if present).

Disko: `local/disk.nix`, applied with `sudo nix run github:nix-community/disko -- --mode disko local/disk.nix`.

**Files to create:** `local/config.nix.example` (tracked in git, mirrors the schema), `local/config.nix` (gitignored, copy of `.example` with real values), `.gitignore` entry for `local/`
**Files to delete:** `user.env`, `user.env.example`

#### `flake.nix` — thin wiring (~25 lines)

```nix
{
  inputs = { ... };  # unchanged

  outputs = { self, nixpkgs, home-manager, vm, shell, ... }@inputs:
    let
      inherit (import ./lib/resolve.nix { inherit inputs self; }) cfg;
      profiles = import ./lib/profiles.nix { inherit (cfg) profiles; };
      outputs = import ./lib/outputs.nix { inherit self inputs cfg profiles; };
    in
    outputs;
}
```

`current` aliases exposed by `lib/outputs.nix` — `nixosConfigurations.current` and `homeConfigurations.current` always resolve from `local/config.nix`. No env vars needed at build time.

______________________________________________________________________

### Phase 3 — Cleanup

Delete all dead code:

| File/Dir | Reason |
|---|---|
| `lib/parseEnv.nix` | Replaced by `resolve.nix` |
| `lib/build/scanHosts.nix` | No more `hosts/` to scan |
| `lib/flake/default.nix` | Replaced by `lib/outputs.nix` |
| `lib/flake/homeConfigurations.nix` | Replaced by `lib/outputs.nix` |
| `lib/flake/checks.nix` | Replaced by `lib/outputs.nix` |
| `lib/flake/shared.nix` | Toolchain logic moved into `resolve.nix`; dev shell logic into `outputs.nix` |
| `common/` (entire dir) | Replaced by profiles |
| `hosts/` (entire dir) | Replaced by `local/config.nix` |
| `lib/virtualisation/default.nix` | Aggregator no longer needed — profiles import individual files directly |
| `user.env` | Replaced by `local/config.nix` |
| `user.env.example` | Replaced by `local/config.nix` template |
| `lib/checks/parseEnv.nix` | Env file format deleted |
| Hardcoded `"proj/angst"` (16 files) | Auto-derived from `self.sourceInfo.outPath` in `resolve.nix` (fallback `"proj/angst"`) |
| Hardcoded `"x86_64-linux"` (5 files) | Centralized in `resolve.nix` |
| Hardcoded `"allowUnfree"` (3 files) | Centralized in `resolve.nix` |

Files under `lib/virtualisation/` that are **kept** (referenced by `profiles/vm.nix` or needed at runtime):

| File | Why kept |
|---|---|
| `is-qemu-vm.nix` | Used by `detect.nix` |
| `detect.nix` | Defines `angst.isQemuVm` option |
| `runtime.nix` | Boot loader logic |
| `specialisation.nix` | VM specialisation |
| `vm-variant.nix` | VM variant config |
| `vm-profile.nix` | VM runtime config |
| `host-mount.nix` | Host mount symlinks |

#### Deferred — follow-up pass after core refactor

- [ ] `tools/vm/flake.nix` — `res` script exports `ANGST_PASSWORD` from `user.env` → read from `local/config.nix`
- [ ] `tools/vm/crates/vm-cli/src/runner/vm.rs` — Rust runner reads `ANGST_PASSWORD` from env → read from config
- [ ] `lib/checks/password.nix` — rewrite tests for `local/config.nix`
- [ ] `lib/checks/parseEnv.nix` — delete (no longer needed after env file format removed)

______________________________________________________________________

### Justfile

```just
setup:
    @read -s -p "Enter password: " pass; echo; \
    read -s -p "Confirm password: " pass2; echo; \
    if [ "$$pass" != "$$pass2" ]; then echo "Passwords don't match"; exit 1; fi; \
    hash=$$(mkpasswd -m sha-512 <<<"$$pass"); \
    sed -i "s|\$6\$CHANGE_ME_REPLACE_WITH_REAL_HASH|$$hash|" local/config.nix

disko:
    sudo nix run github:nix-community/disko -- --mode disko local/disk.nix

hardware:
    nixos-generate-config --show-hardware-config > local/hardware.nix

bootstrap: disko hardware
    @echo "Now write local/config.nix, run 'just setup', then 'just build'"

build:
    nix build --impure .#nixosConfigurations.current

switch:
    sudo nixos-rebuild switch --impure --flake .#current

hm:
    nix build --impure .#homeConfigurations.current.activationPackage

hm-switch:
    nix build --impure .#homeConfigurations.current.activationPackage && ./result/activate

check:
    nix flake check --impure

dev:
    nix develop --impure
```

`current` aliases derive user/host from `local/config.nix` via `resolve.nix` — no shell env vars, no `$USER@$HOST` guesswork.

______________________________________________________________________

### Invariants

- `local/` is **never tracked by git** (entire directory in `.gitignore`)
- Profiles are pure lists of NixOS/HM modules (paths or inline attrsets) — no special framework required
- Existing domain, theme, capability, toolchain structure is untouched
- Domain enablement comes from profiles (inline enable attrsets), domain option definitions come from scan via `mkDomainModule` in builders
- Dev shell always has all toolchains available regardless of profile selection
- Toolchain selection is driven by `config.nix.toolchains`, not by profiles
- No fallback files — `config.nix.nixos` and `config.nix.home` are the only escape hatches
- `flake.nix` stays thin (~25 lines) — just inputs + output wiring
- Profiles compose via module ordering: later modules override earlier ones
- No `hosts/` directory — machine identity comes solely from `local/config.nix`
- No `angst passwd` CLI needed for bootstrap — `mkpasswd` is a standard system tool
- No env re-parsing in builders — `resolve.nix` evaluates everything once
- Env var overrides (`$ANGST_HOST`, `$ANGST_USERNAME`, etc.) require `--impure` at eval time; pure evaluation reads only `local/config.nix`
