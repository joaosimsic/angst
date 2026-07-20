{
  self,
  inputs,
  cfg,
  profiles,
}:

let
  pkgs = import inputs.nixpkgs {
    system = cfg.system;
    config = import ./nixpkgs-config.nix;
  };
  lib = pkgs.lib;

  mkHome = import ./mkHome.nix;
  mkHost = import ./mkNixos.nix;

  hmModules = profiles.hm;
  nixosModules = profiles.nixos;

  vmOutputs = inputs.vm.mkOutputs self;
  shellOutputs = inputs.shell.mkOutputs self;
  vmTool = vmOutputs.packages.${cfg.system}.default;
  shellTool = shellOutputs.packages.${cfg.system}.default;
  angstTool = (
    pkgs.writeShellApplication {
      name = "angst";
      runtimeInputs = with pkgs; [
        coreutils
        findutils
        git
        nix
        watchexec
        jq
      ];
      text = builtins.readFile ../scripts/angst.sh;
    }
  );

  render = import ./render.nix { inherit cfg lib; };

  devshell = import ./devshell.nix {
    inherit
      pkgs
      cfg
      inputs
      vmOutputs
      shellOutputs
      ;
    angstCli = angstTool;
  };

  mkChecks = import ./checks/default.nix {
    inherit
      self
      inputs
      cfg
      profiles
      pkgs
      lib
      render
      ;
  };
in
rec {
  homeConfigurations = {
    current = mkHome {
      inherit
        self
        inputs
        cfg
        hmModules
        vmTool
        shellTool
        angstTool
        ;
    };
    "${cfg.username}" = mkHome {
      inherit
        self
        inputs
        cfg
        hmModules
        vmTool
        shellTool
        angstTool
        ;
    };
    "${cfg.username}@${cfg.hostname}" = mkHome {
      inherit
        self
        inputs
        cfg
        hmModules
        vmTool
        shellTool
        angstTool
        ;
    };
  }
  // {
    "${cfg.username}-theme-override-test" =
      let
        overrideTheme = builtins.head (
          builtins.filter (n: n != cfg.theme) (builtins.attrNames cfg.scan.themes.themes)
        );
      in
      mkHome {
        inherit
          self
          inputs
          cfg
          hmModules
          vmTool
          shellTool
          angstTool
          ;
        themeOverride = overrideTheme;
      };
  };

  nixosConfigurations = {
    current = mkHost {
      inherit
        self
        inputs
        cfg
        hmModules
        nixosModules
        ;
    };
    "${cfg.hostname}" = mkHost {
      inherit
        self
        inputs
        cfg
        hmModules
        nixosModules
        ;
    };
  };

  packages.${cfg.system} = {
    default = homeConfigurations.current.activationPackage;
    angst = angstTool;
    vm-cli = vmOutputs.packages.${cfg.system}.wrapped;
    vm = vmOutputs.packages.${cfg.system}.wrapped;
    vm-run = vmOutputs.packages.${cfg.system}.vm-run;
    res = vmOutputs.packages.${cfg.system}.res;
    shell = shellTool;
  };

  devShells.${cfg.system} = devshell.shells;

  apps.${cfg.system} = {
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

  checks.${cfg.system} = mkChecks;

  formatter.${cfg.system} = pkgs.nixfmt;

  lib = {
    inherit (render) renderDomainOutputsFor renderDomainOutputFor;
    themeLint =
      mkChecks.themeLint or (import ./checks/theme {
        inherit lib;
        themesLib = cfg.scan.themes;
        renderDomainOutputsFor = render.renderDomainOutputsFor;
      });
  };
}
