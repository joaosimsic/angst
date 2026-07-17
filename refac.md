# Introduction

The idea is to refac my whole nix repo, there are several flaws descripted on `analysis.md` that are apparent in build time and usage of the system.

# Use cases

There are various use cases that i want to cover that were made difficult by the current architecture. I've been running this system on various hosts ranging from virtual machine, NixOS system and regular linux distro which have only access to nix package manager, and each host have its peculiarities like only using the system via ssh, only needing some specific toolchains for a debian server or running only home-manager in a regular linux distro.

# Problems

- There's no differentiation between home-manager related packages and NixOS configurations, they are all bundled together meaning i have little control how to run the system under different conditions.
- I'm forced to create a new host for every machine that ill run the system, even though i cant possibly predict if i will need the system to work in a completely different host. this obligates me to know beforehand or to spend some time into creating a unique host if i ever want to use the system
- Since flake is based on git, it inherits all of the system's state such as user, themes and any other host specific configurations. Since i might use each host differently, i must be able to keep the system requirements outside git, allowing me to manage the way and reason im going to use it without have conflicts with new system versions or changes.
- There are several bottlenecks listed in `analysis.md` that makes the build time largely bigger than i must be.

<!-- dont edit the text above -->

______________________________________________________________________

## Plan

### Core idea

`local/config.nix` (gitignored) is the **source of truth** for machine identity — includes `repoPath`, hostname, username, theme, monitors, profiles, toolchains, and machine-local settings. **Profiles** (under `profiles/`) are reusable bundles of co-dependent configs — e.g., `desktop` enables i3 + bar + launcher + graphical capabilities as a unit. `lib/read-config.nix` reads `local/config.nix` purely — no impurity, no env vars. All scan functions are called once, centrally — no duplicate scanning, no I/O in builders.

Existing domain/theme/capability/toolchain structure is **untouched** — only the wiring around them changes.

______________________________________________________________________

### Phase 1 — Core

All new files created. `lib/build/mkHome.nix` and `lib/build/mkHost.nix` are **overwritten** with the new interface — the old `flake.nix` will break immediately. That's fine; Phase 2 wires everything back together.

#### `lib/read-config.nix` — pure config reader

Reads `local/config.nix` only — no `builtins.getEnv`. Resolves toolchains (unset/`"*"` → all, list → specific), calls existing scan functions once.

> **Impure evaluation:** `local/config.nix` is gitignored, so it's not available in the Nix store. Evaluation requires `--impure` (same as the current `user.env` approach). `nix flake show`, `nix flake check`, `nix build .#...` all work with `--impure`.
>
> **Self-flake only:** `local/` is gitignored so `builtins.pathExists ../local/config.nix` will never find the file when evaluated from the Nix store (e.g., when pinned as a remote input). This flake is designed to be evaluated from a working `git clone` only.

```nix
# lib/read-config.nix — pure config reader
#
# Toolchains are evaluated once into an indexed map, then shared by
# both `scan.allToolchainPackages`/`treesitter` and `toolchainModules`.
# No duplicate scanning, no I/O in builders.
{ inputs, self }:

let
  configPath = if builtins.pathExists ../local/config.nix
               then ../local/config.nix
               else builtins.throw "Create local/config.nix (see local/config.nix.example)";
  config = import configPath;
  system = config.system or "x86_64-linux";
  pkgs = import inputs.nixpkgs { inherit system; config.allowUnfree = true; };
  lib = pkgs.lib;

  # Toolchain evaluation — once, indexed by bare name
  _toolchainDir = ../toolchains;
  _rawFiles = builtins.attrNames (
    lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix")
      (builtins.readDir _toolchainDir)
  );
  _tcIndex = lib.listToAttrs (map (f:
    let name = lib.removeSuffix ".nix" f;
    in { inherit name; value = import (_toolchainDir + "/${f}") { inherit lib pkgs; }; }
  ) _rawFiles);
  _allTCs = builtins.attrValues _tcIndex;

  domainsLib = import ../lib/domains/default.nix { inherit lib; domainsPath = ../domains; };
  themesLib  = import ../themes/default.nix { inherit lib; };
in

# Helpers exported alongside cfg (used by lib/profiles.nix)
{
  inherit _tcIndex _allTCs;

  cfg = {
    system     = config.system or "x86_64-linux";
    hostname   = config.hostname;
    username   = config.username;
    theme      = config.theme or "monochrome";
    password   = config.password;
    monitors   = config.monitors or {};
    profiles   = config.profiles or [ "base" ];
    toolchains = config.toolchains or "*";
    repoPath   = config.repoPath;
    extraNixos = config.nixos or {};
    extraHome  = config.home or {};

    # resolved from scan (evaluated once here, not by builders)
    scan = {
      domains = domainsLib;
      themes = themesLib;
      allToolchainPackages = lib.unique (lib.concatMap (t: t.home.packages or []) _allTCs);
      treesitter = import ../lib/treesitter.nix {
        inherit lib pkgs;
        grammars = lib.unique (lib.concatMap (t: t.toolchains.treesitterGrammars or []) _allTCs);
      };
    };

    # toolchain modules — shares _tcIndex with scan (no re-import)
    toolchainModules =
      let bareNames = builtins.attrNames _tcIndex;
      in if config.toolchains == "*" then _allTCs
         else if builtins.isList config.toolchains then
           let unknown = builtins.filter (n: !builtins.elem n bareNames) config.toolchains;
           in if unknown != []
             then builtins.throw "Unknown toolchains: ${builtins.concatStringsSep ", " unknown}. Valid: ${builtins.concatStringsSep ", " bareNames}"
             else map (n: _tcIndex.${n}) config.toolchains
         else builtins.throw "toolchains must be \"*\" or a list";
  };
}
```

#### Profiles (`profiles/`)

Each profile returns `{ hm, nixos }` — two lists of NixOS/HM modules (paths or inline attrsets).

Domain custom modules (e.g., `domains/wm/i3/module.nix`) depend on `config.domains.wm.i3.enable` which is **defined by `mkDomainModule` from the scan system**, not by the module file itself. So profiles can't list domain `module.nix` paths directly. Instead, profile `hm` lists **enable modules** via `mkDomainEnable` — a helper that validates domain names against the scan at eval time, throwing with an available-list error if the domain doesn't exist. The builders still import all domain modules via `mkDomainModule` from `cfg.scan.domains`; profiles just decide which ones are active.

**`lib/mkDomainEnable.nix`** — validates domain names at eval time so renames fail early:

```nix
# lib/mkDomainEnable.nix
{ lib, scan }:

name:
let
  entries = scan.domains.homeEntries ++ scan.domains.nixosEntries;
  domain = lib.findFirst (e: "${e.category}.${e.name}" == name) null entries;
in
if domain == null then
  builtins.throw "Unknown domain '${name}'. Available: ${builtins.concatStringsSep ", " (map (e: "${e.category}.${e.name}") entries)}"
else {
  domains.${domain.category}.${domain.name}.enable = true;
}
```

```nix
# profiles/desktop.nix
{ mkDomainEnable }:
{
  hm = [
    (mkDomainEnable "wm.i3")
    (mkDomainEnable "bar.i3status")
    (mkDomainEnable "launcher.rofi")
    (mkDomainEnable "terminal.ghostty")
  ];
  nixos = [
    ../capabilities/graphical.nix
    ../capabilities/audio.nix
    ../capabilities/clipboard.nix
  ];
}
```

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

> **Migration note:** The current `common/home.nix` enables everything from `base` + `development` (nushell, starship, zellij, nvim, yazi, lazygit, opencode, cursor-cli, sqlit, posting) plus `common/capabilities.nix` (network, git, search, monitoring, containers). To match the old setup, use `profiles = ["base" "development"]`. Note `desktop` is a superset that adds i3, i3status, rofi, ghostty and graphical/audio/clipboard capabilities — you'd still include `base` + `development` alongside it if you want those tools.

**Profile resolution** (`lib/profiles.nix`):

```nix
# lib/profiles.nix
{ profiles, lib, scan }:

let
  mkDomainEnable = import ./mkDomainEnable.nix { inherit lib scan; };

  profileMap = {
    base        = import ../profiles/base.nix        { inherit mkDomainEnable; };
    desktop     = import ../profiles/desktop.nix      { inherit mkDomainEnable; };
    development = import ../profiles/development.nix  { inherit mkDomainEnable; };
    server      = import ../profiles/server.nix       { inherit mkDomainEnable; };
    vm          = import ../profiles/vm.nix           { inherit mkDomainEnable; };
  };

  resolve = names:
    let
      validNames = builtins.attrNames profileMap;
      unknown = builtins.filter (n: !builtins.elem n validNames) names;
    in
    if unknown != []
    then builtins.throw "Unknown profiles: ${builtins.concatStringsSep ", " unknown}. Valid: ${builtins.concatStringsSep ", " validNames}"
    else {
      hm    = lib.concatMap (n: profileMap.${n}.hm)  names;
      nixos = lib.concatMap (n: profileMap.${n}.nixos) names;
    };
in
resolve profiles
```

No toolchain imports in profiles — toolchain selection is driven by `config.nix.toolchains`. Same validation pattern applies to toolchain names in `profiles.nix`.

**Files to create:** `profiles/base.nix`, `profiles/desktop.nix`, `profiles/development.nix`, `profiles/server.nix`, `profiles/vm.nix`, `lib/profiles.nix`, `lib/mkDomainEnable.nix`

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

> `vmTool`, `shellTool`, and `angstTool` are always included — they're lightweight shell-script wrappers (not heavy closures like QEMU or Rust) and are harmless on all profiles. For server-only deployments, exclude them via `cfg.extraHome`.

**Files to modify:** `lib/build/mkHome.nix` (overwrites old interface — see Phase 1 header note)

#### `lib/build/mkHost.nix` — pure builder

Same pattern as `mkHome.nix`: imports all domain NixOS modules from scan, then profile nixos modules on top. `hardware.nix` path is derived from `${toString self}/local/hardware.nix` (resolves the flake root at eval time). Must pass `userConfig`/`repoPath` in `specialArgs` for `vm-variant.nix`, `host-mount.nix`, etc.

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
    ++ (if builtins.pathExists "${toString self}/local/hardware.nix" then [ (import "${toString self}/local/hardware.nix") ] else [])
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

**Files to modify:** `lib/build/mkHost.nix` (overwrites old interface)

#### `lib/outputs.nix` — pure wiring

Replaces `lib/flake/default.nix` (397 LOC, fan-out 12). Dev shells and inline tools (`vmRunShim`, `resWrapper`) are kept in their respective tool flakes. Tool definitions (`angstCli`) live in `lib/tools.nix`. Render logic lives in `lib/render.nix`. Dev shells live in `lib/devshell.nix`. Checks live in `lib/checks/default.nix`. `outputs.nix` imports each part and wires them together — under 150 LOC.

```nix
# lib/outputs.nix
{ self, inputs, cfg, profiles }:

let
  pkgs = import inputs.nixpkgs { system = cfg.system; config.allowUnfree = true; };
  lib = pkgs.lib;

  mkHome = import ./build/mkHome.nix;
  mkHost = import ./build/mkHost.nix;

  hmModules    = profiles.hm;
  nixosModules = profiles.nixos;

  # tool flake outputs (vmRunShim/resWrapper kept in their own flakes)
  vmOutputs    = inputs.vm.mkOutputs self;
  shellOutputs = inputs.shell.mkOutputs self;
  vmTool       = vmOutputs.packages.${cfg.system}.default;
  shellTool    = shellOutputs.packages.${cfg.system}.default;
  angstTool    = (import ./tools.nix { inherit pkgs; }).angstCli;

  # render logic
  render = import ./render.nix { inherit cfg lib; };

  # dev shells
  devshell = import ./devshell.nix { inherit pkgs cfg inputs vmOutputs shellOutputs; angstCli = angstTool; };

  # checks
  mkChecks = import ./checks/default.nix {
    inherit self inputs cfg profiles pkgs lib render;
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

  packages.${cfg.system} = {
    default = homeConfigurations.current.activationPackage;
    angst   = angstTool;
    vm-cli  = vmOutputs.packages.${cfg.system}.wrapped;
    vm      = vmOutputs.packages.${cfg.system}.wrapped;
    vm-run  = vmOutputs.packages.${cfg.system}.vm-run;
    res     = vmOutputs.packages.${cfg.system}.res;
    shell   = shellTool;
  };

  devShells.${cfg.system} = devshell.shells;

  apps.${cfg.system} = {
    vm = { type = "app"; program = "${vmOutputs.packages.${cfg.system}.wrapped}/bin/vm"; };
    shell = { type = "app"; program = "${shellTool}/bin/shell"; };
    angst = { type = "app"; program = "${angstTool}/bin/angst"; };
    render = { type = "app"; program = "${pkgs.writeShellScript "angst-render" ''exec ${angstTool}/bin/angst render "$@"''}"; };
    watch = { type = "app"; program = "${pkgs.writeShellScript "angst-watch" ''exec ${angstTool}/bin/angst watch "$@"''}"; };
    check = { type = "app"; program = "${pkgs.writeShellScript "check" ''set -euo pipefail; ${pkgs.nix}/bin/nix flake check --print-build-logs''}"; };
    lint-themes = { type = "app"; program = "${pkgs.writeShellScript "lint-themes" ''set -euo pipefail; ${pkgs.nix}/bin/nix eval ${self}#lib.themeLint --raw''}"; };
    lint-desktop = { type = "app"; program = "${pkgs.writeShellScript "lint-desktop" ''set -euo pipefail; ${pkgs.nix}/bin/nix build ${self}#checks.${cfg.system}.lint-desktop --no-link --print-build-logs; echo "All desktop config checks passed."''}"; };
    lint-shell = { type = "app"; program = "${pkgs.writeShellScript "lint-shell" ''set -euo pipefail; ${pkgs.nix}/bin/nix build ${self}#checks.${cfg.system}.lint-shell --no-link --print-build-logs; echo "All shell config checks passed."''}"; };
    analyze = { type = "app"; program = "${pkgs.writeShellScript "analyze" ''exec python3 -m scripts.analyze_flake "$@"''}"; };
    analyze-to-file = { type = "app"; program = "${pkgs.writeShellScript "analyze-to-file" ''cd "$(git rev-parse --show-toplevel)" && exec python3 -m scripts.analyze_flake --output analysis.md "$@"''}"; };
    ssh = { type = "app"; program = "${pkgs.writeShellScript "angst-ssh-deploy" ''
      set -euo pipefail
      echo "==> Building & activating ${cfg.username}@${cfg.hostname}..."
      nix build ${self}#homeConfigurations.${cfg.username}@${cfg.hostname}.activationPackage --print-build-logs
      echo "==> Activating..."; ./result/activate
      echo "==> Cleaning old Nix store..."; nix-collect-garbage -d; nix store gc; echo "==> Done."
    ''}"; };
  };

  checks = mkChecks;

  formatter.${cfg.system} = pkgs.nixfmt;

  lib = {
    inherit (render) renderDomainOutputsFor renderDomainOutputFor;
    themeLint = mkChecks.themeLint or (import ../checks/theme {
      inherit lib;
      themesLib = cfg.scan.themes;
      renderDomainOutputsFor = render.renderDomainOutputsFor cfg.hostname;
    });
  };
}
```

**`lib/tools.nix`** — angst CLI wrapper only (previously in `shared.nix`):
```nix
{ pkgs }: {
  angstCli = pkgs.writeShellApplication {
    name = "angst";
    runtimeInputs = with pkgs; [ coreutils findutils git nix watchexec jq ];
    text = builtins.readFile ./scripts/angst.sh;
  };
}
```

**`lib/render.nix`** — domain render logic extracted from `outputs.nix`:
```nix
{ cfg, lib }:

let
  fontsLib = import ../home/fonts.nix;
in rec {
  # hostName is accepted for API compat with existing callers (not used — cfg has everything)
  renderDomainOutputsFor = hostName: themeName:
    let
      themesLib = cfg.scan.themes;
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
}
```

**`lib/devshell.nix`** — dev shells extracted from `outputs.nix`:
```nix
{ pkgs, cfg, inputs, angstCli, vmOutputs, shellOutputs }:

let
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
in {
  shells = {
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
}
```

> `vmRunShim` and `resWrapper` are **not** inlined here — they live in `tools/vm/flake.nix` and `tools/shell/flake.nix` respectively, exposed as `vm-run` and `res` packages. Update those flakes in Phase 3 to read from `local/config.nix` instead of `user.env`.

No `common/`, `hosts/`, `user.env`, or env re-parsing involved.

**`lib/checks/default.nix`** — adapted from `lib/flake/checks.nix`, uses `cfg` instead of `user.env`/`loadHost`:

```nix
# lib/checks/default.nix
{ self, inputs, cfg, profiles, pkgs, lib, render }:

let
  inherit (lib) attrNames filter head;

  themesLib = cfg.scan.themes;
  alternate = head (filter (n: n != cfg.theme) (attrNames themesLib.themes));

  themeLint = import ../../checks/theme {
    inherit lib;
    themesLib = cfg.scan.themes;
    renderDomainOutputsFor = render.renderDomainOutputsFor cfg.hostname;
  };

  lintDesktop = import ../../checks/desktop.nix {
    inherit lib pkgs;
    themesLib = cfg.scan.themes;
    renderDomainOutputFor = render.renderDomainOutputFor cfg.hostname;
  };

  lintShell = import ../../checks/shell.nix {
    inherit lib pkgs;
    themesLib = cfg.scan.themes;
    renderDomainOutputFor = render.renderDomainOutputFor cfg.hostname;
  };

  themeRendered = import ../../checks/theme/rendered.nix {
    inherit lib pkgs;
    themesLib = cfg.scan.themes;
    renderDomainOutputsFor = render.renderDomainOutputsFor cfg.hostname;
    themeName = cfg.theme;
  };

  themeSemanticDistinct = import ../../checks/theme/semanticDistinct.nix {
    inherit lib pkgs;
    themesLib = cfg.scan.themes;
    themeName = cfg.theme;
  };

  themeOverrideCheck = import ../../checks/theme/override.nix {
    inherit lib pkgs themesLib;
    overrideTheme = alternate;
    renderDomainOutputFor = render.renderDomainOutputFor cfg.hostname;
    homeConfiguration = self.homeConfigurations."${cfg.username}-theme-override-test";
  };

  # check-password: deferred to Phase 3 (needs rewrite for local/config.nix)
in
{
  lint-themes           = pkgs.writeText "lint-themes-check" themeLint;
  lint-desktop          = lintDesktop;
  lint-shell            = lintShell;
  theme-rendered        = themeRendered;
  theme-override        = themeOverrideCheck;
  theme-semantic-distinct = themeSemanticDistinct;
  home-theme-override-test = self.homeConfigurations."${cfg.username}-theme-override-test".activationPackage;
}
```

**Files to create:** `lib/outputs.nix`, `lib/tools.nix`, `lib/render.nix`, `lib/devshell.nix`, `lib/checks/default.nix`

______________________________________________________________________

### Phase 2 — `local/` + `flake.nix`

#### `local/` directory

- Create `local/` directory, add to `.gitignore`
- `local/config.nix` is the **sole source of machine identity** — no fallback files:

```nix
# local/config.nix — machine identity (gitignored)
#
# Generate password hash:
#   mkpasswd -m sha-512
# Then paste the hash as the password value below.
#
# repoPath: relative path from $HOME to this git checkout.
#   The activation scripts resolve config dirs from $HOME/$repoPath.
#   On NixOS this is typically "proj/angst".
#   Verify with: git rev-parse --show-prefix
#
# toolchains: "*" for all, or a list like ["bash" "nix" "php"]
#             for a minimal server setup.
{
  system = "x86_64-linux";
  repoPath = "proj/angst";
  hostname = "personal";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development"];
  toolchains = "*";

  # Hashed password — NOT plaintext. Generate with: mkpasswd -m sha-512
  password = "$6$CHANGE_ME_REPLACE_WITH_REAL_HASH";

  monitors.primary = {
    name = "DP-1";
    resolution = "1920x1080";
    refreshRate = 144;
    position = "0x0";
  };

  nixos = {};  # one-off NixOS config (replaces host-specific configuration.nix)
  home = {};   # one-off HM config (replaces host-specific home.nix)
}
```

No `local/home.nix`, `local/configuration.nix`, or any other fallback file. The `nixos` and `home` attrs are the only escape hatch. Auto-merged as additional modules by the builders.

Hardware: `nixos-generate-config --show-hardware-config > local/hardware.nix` (auto-imported if present).

Disko: `local/disk.nix`, applied with `sudo nix run github:nix-community/disko -- --mode disko local/disk.nix`.

**Files to create:** `local/config.nix.example` (tracked in git, mirrors the schema), `local/config.nix` (gitignored, copy of `.example` with real values), `.gitignore` entry for `local/` (add `local/` and `!local/config.nix.example` to `.gitignore` alongside existing `user.env`)
**Files to delete:** `user.env`, `user.env.example`

#### `flake.nix` — thin wiring (~25 lines)

Replaces the old `flake.nix` with a ~25-line version that wires `read-config.nix` → `profiles.nix` → `outputs.nix`.

```nix
{
  inputs = { ... };  # unchanged

  outputs = { self, nixpkgs, home-manager, vm, shell, ... }@inputs:
    let
      pure  = import ./lib/read-config.nix { inherit inputs self; };
      cfg   = pure.cfg;
      pkgs  = import nixpkgs { system = cfg.system; config.allowUnfree = true; };
      profiles = import ./lib/profiles.nix {
        inherit (cfg) profiles;
        lib = pkgs.lib;
        scan = cfg.scan;
      };
    in
    import ./lib/outputs.nix { inherit self inputs cfg profiles; };
}
```

`current` aliases exposed by `lib/outputs.nix` — `nixosConfigurations.current` and `homeConfigurations.current` always resolve from `local/config.nix`. No env vars needed at build time. All commands (`nix flake show`, `nix flake check`, `nix build`) work with `--impure` (required because `local/` is gitignored).

#### Scripts — update from `user.env`/`hosts/` to `local/config.nix`

These scripts currently read `user.env` and/or rely on the `hosts/` directory — they must be updated before Phase 3 deletes both:

| File | Current behavior | New behavior |
|---|---|---|
| `scripts/angst.sh` | `repo_root_default()` checks for `hosts/` dir; `env_default()` reads `HOST`/`THEME` from `user.env`; `watch_cmd` watches `hosts/$host_name` | Detect repo root by checking for `local/config.nix`; parse config via `nix eval --impure`; watch `local/` instead. Below are the new implementations: |

> **New `repo_root_default()`:**
> ```bash
> repo_root_default() {
>     local dir="$PWD"
>     while [ "$dir" != "/" ]; do
>         if [ -f "$dir/local/config.nix" ]; then
>             printf '%s\n' "$dir"
>             return
>         fi
>         dir="$(dirname "$dir")"
>     done
>     git rev-parse --show-toplevel 2>/dev/null || pwd
> }
> ```
> **New `env_default()` replaced by direct config reads** (no per-field grep, single `nix eval` call):
> ```bash
> config_val() {
>     local repo="$1" key="$2"
>     nix eval --impure --expr "(import $repo/local/config.nix).$key" --raw 2>/dev/null || true
> }
> ```
> **`watch_cmd`** watches `$repo_root/local/` instead of `hosts/$host_name`.

| `tools/vm/flake.nix` (`vm-run` script) | Reads `HOST` from `user.env` at lines 92-97; has `hostUserCases` hardcoded case statement (lines 78-87) mapping hostname→username | Read hostname via `nix eval --impure --expr '(import $FLAKE_DIR/local/config.nix).hostname' --raw`; username from same file's `.username`; delete the hardcoded `hostUserCases` |
| `tools/vm/flake.nix` (`res` script) | Reads `HOST`, `USERNAME`, `THEME`, `PASSWORD` from `user.env` at lines 152-184 | Read from `local/config.nix` using same `nix eval --impure` pattern for each field; export `ANGST_PASSWORD` from config's `.password` hash |
| `tools/vm/crates/vm-cli/src/runner/vm.rs` | `read_env_value()` looks for `user.env`; `ANGST_PASSWORD` read from env (lines 270-273) | Remove `user.env` fallback; `ANGST_PASSWORD` is exported by the wrapper script (bash reads `local/config.nix` and sets env var before calling the Rust binary) |
| `tools/shell/src/runner.rs` | `read_env_value()` looks for `user.env` (lines 56-60) | Remove `user.env` fallback; config is passed via env vars from `devshell.nix` |

No new files — these are modifications to existing scripts.

______________________________________________________________________

### Phase 3 — Cleanup

Delete all dead code:

| File/Dir | Reason |
|---|---|
| `lib/parseEnv.nix` | Replaced by `read-config.nix` |
| `lib/build/scanHosts.nix` | No more `hosts/` to scan |
| `lib/flake/default.nix` | Replaced by `lib/outputs.nix` |
| `lib/flake/homeConfigurations.nix` | Replaced by `lib/outputs.nix` |
| `lib/flake/checks.nix` | Replaced by `lib/outputs.nix` |
| `lib/flake/shared.nix` | Toolchain logic moved into `read-config.nix`; dev shell logic into `devshell.nix`; `angstCli` into `tools.nix` |
| `common/` (entire dir) | Replaced by profiles |
| `hosts/` (entire dir) | Replaced by `local/config.nix` |
| `lib/virtualisation/default.nix` | Aggregator no longer needed — profiles import individual files directly |
| `capabilities/default.nix` | Aggregator no longer needed — profiles import individual capability files directly |
| `user.env` | Replaced by `local/config.nix` |
| `user.env.example` | Replaced by `local/config.nix` template |
| `lib/checks/parseEnv.nix` | Env file format deleted |
| Hardcoded `"proj/angst"` (16 files) | Explicit field in `local/config.nix` — each machine sets its own `repoPath` |
| Hardcoded `"x86_64-linux"` (5 files) | Centralized in `read-config.nix` |
| Hardcoded `"allowUnfree"` (3 files) | Centralized in `read-config.nix` |
| `hostUserCases` case statement (`tools/vm/flake.nix:78-87`) | Replaced by `local/config.nix` read at runtime |

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

- [ ] `lib/checks/password.nix` — rewrite tests for `local/config.nix` (env var test replaced, CLI test removed)

> **Known:`nix flake check` will show `check-password` as failed after Phase 2** since it tests the old `angst passwd` CLI and `user.env` file. The failure is non-fatal (doesn't block builds). Rewrite `lib/checks/password.nix` before considering the refactor finished.

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
    nix build .#nixosConfigurations.current

switch:
    sudo nixos-rebuild switch --flake .#current

hm:
    nix build .#homeConfigurations.current.activationPackage

hm-switch:
    nix build .#homeConfigurations.current.activationPackage && ./result/activate

check:
    nix flake check

dev:
    nix develop

```

`current` aliases derive user/host from `local/config.nix` — no shell env vars, no `$USER@$HOST` guesswork.

______________________________________________________________________

### Invariants

- `local/` is **never tracked by git** (entire directory in `.gitignore`)
- Profiles are pure lists of NixOS/HM modules (paths or inline attrsets) — no special framework required
- Existing domain, theme, capability, toolchain structure is untouched
- Domain enablement comes from profiles via `mkDomainEnable` helper (validates domain names against scan at eval time), domain option definitions come from scan via `mkDomainModule` in builders
- Dev shell always has all toolchains available regardless of profile selection
- Toolchain selection is driven by `config.nix.toolchains`, not by profiles
- No fallback files — `config.nix.nixos` and `config.nix.home` are the only escape hatches
- `flake.nix` stays thin (~25 lines) — just inputs + output wiring
- Profiles compose via module ordering: later modules override earlier ones
- No `hosts/` directory — machine identity comes solely from `local/config.nix`
- `angst passwd` CLI removed — use `just setup` instead
- No env re-parsing in builders — `read-config.nix` evaluates everything once
- All operations (`nix flake show`, `nix flake check`, `nix build`) work with `--impure` — `local/config.nix` is the sole source of truth (impure is required because `local/` is gitignored and unavailable from the Nix store)
- Self-flake only: must be evaluated from a working `git clone` — `local/` is gitignored so it won't be found if the flake is used as a remote input
- `repoPath` is an explicit field in `local/config.nix` (not auto-derived) — each machine declares its own checkout path
- `vmRunShim`/`resWrapper` live in `tools/vm` and `tools/shell` flakes, not inlined in the main flake output
- `outputs.nix` stays under 150 LOC by splitting dev shells (`devshell.nix`), renders (`render.nix`), tools (`tools.nix`), and checks (`checks/default.nix`) into separate files
