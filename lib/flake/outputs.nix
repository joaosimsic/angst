{
  self,
  inputs,
  hostCfgs,
  themesLib,
}:

let
  inherit (inputs.nixpkgs) lib;

  cfgList = builtins.attrValues hostCfgs;
  nixosHosts = builtins.filter (h: h.type == "nixos") cfgList;
  firstNixOS = if nixosHosts != [ ] then builtins.elemAt nixosHosts 0 else null;
  firstHost = if cfgList != [ ] then builtins.elemAt cfgList 0 else null;
  representative = if firstNixOS != null then firstNixOS else firstHost;

  defaultSystem =
    if firstNixOS != null then firstNixOS.system
    else if firstHost != null then firstHost.system
    else "x86_64-linux";

  pkgs = import inputs.nixpkgs {
    system = defaultSystem;
    config = import ../nixpkgs-config.nix;
  };

  profilesFor =
    cfg:
    import ../../profiles/default.nix {
      inherit (cfg) profiles;
      inherit lib;
      inherit (cfg) scan;
    };

  mkHome = import ../build/mkHome.nix;
  mkHost = import ../build/mkNixos.nix;

  vmOutputs = inputs.vm.mkOutputs self;
  shellOutputs = inputs.shell.mkOutputs self;
  vmTool = vmOutputs.packages.${defaultSystem}.default or vmOutputs.packages.${defaultSystem}.vm;
  shellTool = shellOutputs.packages.${defaultSystem}.default;

  angstTool = pkgs.writeShellApplication {
    name = "angst";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      git
      nix
      watchexec
      jq
    ];
    text = builtins.readFile ../../scripts/angst.sh;
  };

  render = import ../render.nix {
    cfg =
      if representative != null then
        representative
      else
        {
          scan = {
            domains.homeEntries = [ ];
            themes = themesLib;
          };
          monitors = { };
          db = { };
          sshAgent = { };
          username = "user";
        };
    inherit lib;
  };

  devshell = import ./devshell.nix {
    inherit
      pkgs
      inputs
      vmOutputs
      ;
    cfg = representative;
    angstCli = angstTool;
  };

  mkChecks = import ../../checks/default.nix {
    inherit
      self
      inputs
      pkgs
      lib
      render
      ;
    cfg = representative;
  };
in
rec {
  nixosConfigurations = builtins.listToAttrs (
    map (
      cfg:
      let
        p = profilesFor cfg;
      in
      {
        name = cfg.hostname;
        value = mkHost {
          inherit self inputs cfg;
          hmModules = p.hm;
          nixosModules = p.nixos;
        };
      }
    ) nixosHosts
  );

  homeConfigurations =
    builtins.listToAttrs (
      map (
        cfg:
        let
          p = profilesFor cfg;
        in
        {
          name = "${cfg.username}@${cfg.hostname}";
          value = mkHome {
            inherit self inputs cfg vmTool shellTool angstTool;
            hmModules = p.hm;
          };
        }
      ) cfgList
    )
    // (if representative != null then (
      let
        r = representative;
        p = profilesFor r;
      in
      {
        "${r.username}" = mkHome {
          inherit self inputs vmTool shellTool angstTool;
          cfg = r;
          hmModules = p.hm;
        };

        "${r.username}-theme-override-test" =
          let
            overrideTheme = builtins.head (
              builtins.filter (n: n != r.theme) (builtins.attrNames r.scan.themes.themes)
            );
          in
          mkHome {
            inherit self inputs vmTool shellTool angstTool;
            cfg = r;
            hmModules = p.hm;
            themeOverride = overrideTheme;
            shellOverride = "";
          };

        login-shell-valid = mkHome {
          inherit self inputs vmTool shellTool angstTool;
          cfg = r;
          hmModules = p.hm;
          shellOverride = "sh";
        };

        login-shell-invalid = mkHome {
          inherit self inputs vmTool shellTool angstTool;
          cfg = r;
          hmModules = p.hm;
          shellOverride = "__angst_nonexistent_shell__";
        };
      }
    ) else { } );

  packages.${defaultSystem} = if representative != null then {
    default = homeConfigurations.${representative.username}.activationPackage;
    angst = angstTool;
    vm-cli = vmOutputs.packages.${defaultSystem}.wrapped;
    vm = vmOutputs.packages.${defaultSystem}.wrapped;
    vm-run = vmOutputs.packages.${defaultSystem}.vm-run;
    res = vmOutputs.packages.${defaultSystem}.res;
    shell = shellTool;
  }
  else { };

  devShells.${defaultSystem} = devshell.shells;

  apps.${defaultSystem} = {
    vm = {
      type = "app";
      program = "${vmOutputs.packages.${defaultSystem}.wrapped}/bin/vm";
    };
    shell = {
      type = "app";
      program = "${shellTool}/bin/shell";
    };
    angst = {
      type = "app";
      program = "${angstTool}/bin/angst";
    };
    render = {
      type = "app";
      program = "${pkgs.writeShellScript "angst-render" ''exec ${angstTool}/bin/angst render "$@"''}";
    };
    watch = {
      type = "app";
      program = "${pkgs.writeShellScript "angst-watch" ''exec ${angstTool}/bin/angst watch "$@"''}";
    };
    check = {
      type = "app";
      program = "${pkgs.writeShellScript "check" "set -euo pipefail; ${pkgs.nix}/bin/nix flake check --print-build-logs"}";
    };
    lint-themes = {
      type = "app";
      program = "${pkgs.writeShellScript "lint-themes" "set -euo pipefail; ${pkgs.nix}/bin/nix eval ${self}#lib.themeLint --raw"}";
    };
    lint-desktop = {
      type = "app";
      program = "${pkgs.writeShellScript "lint-desktop" ''set -euo pipefail; ${pkgs.nix}/bin/nix build ${self}#checks.${defaultSystem}.lint-desktop --no-link --print-build-logs; echo "All desktop config checks passed."''}";
    };
    lint-shell = {
      type = "app";
      program = "${pkgs.writeShellScript "lint-shell" ''set -euo pipefail; ${pkgs.nix}/bin/nix build ${self}#checks.${defaultSystem}.lint-shell --no-link --print-build-logs; echo "All shell config checks passed."''}";
    };
    analyze = {
      type = "app";
      program = "${pkgs.writeShellScript "analyze" ''exec python3 -m scripts.analyze_flake "$@"''}";
    };
    analyze-to-file = {
      type = "app";
      program = "${pkgs.writeShellScript "analyze-to-file" ''cd "$(git rev-parse --show-toplevel)" && exec python3 -m scripts.analyze_flake --output analysis.md "$@"''}";
    };
  }
  // (if representative != null then {
    ssh = {
      type = "app";
      program =
        let
          target = representative.username;
        in
        "${pkgs.writeShellScript "angst-ssh-deploy" ''
          set -euo pipefail
          target="''${NIX_DEFAULT_TARGET_HOST:-${target}}"
          echo "==> Deploying home-manager to $target..."
          nix build ${self}#homeConfigurations.${target}.activationPackage --print-build-logs
          echo "==> Activating..."; ./result/activate
          echo "==> Cleaning old Nix store..."; nix-collect-garbage -d; nix store gc; echo "==> Done."
        ''}";
    };
  } else { } );

  checks.${defaultSystem} = mkChecks;

  formatter.${defaultSystem} = pkgs.nixfmt;

  lib = {
    inherit (render) renderDomainOutputsFor renderDomainOutputFor;
    themeLint =
      mkChecks.themeLint or (import ../../checks/theme {
        inherit lib;
        inherit themesLib;
        inherit (render) renderDomainOutputsFor;
      });
  };
}
