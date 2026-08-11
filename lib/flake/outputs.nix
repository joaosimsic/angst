{
  self,
  inputs,
  hostDefs,
  themesLib,
}:

let
  inherit (inputs.nixpkgs) lib;

  hostList = builtins.attrValues hostDefs;
  nixosHosts = builtins.filter (h: h.type == "nixos") hostList;
  representative =
    if nixosHosts != [ ] then builtins.head nixosHosts
    else if hostList != [ ] then builtins.head hostList
    else null;
  defaultSystem = if representative != null then representative.system else "x86_64-linux";

  pkgs = import inputs.nixpkgs {
    system = defaultSystem;
    config = import ../nixpkgs-config.nix;
  };

  profilesFor =
    host:
    import ../../profiles/default.nix {
      inherit (host) profiles scan;
      inherit lib;
    };

  mkHome = import ../build/mkHome.nix;
  mkHost = import ../build/mkNixos.nix;

  vmOutputs = inputs.vm.mkOutputs self;
  shellOutputs = inputs.shell.mkOutputs self;
  vmTool = vmOutputs.packages.${defaultSystem}.default or vmOutputs.packages.${defaultSystem}.vm;
  vmResTool = vmOutputs.packages.${defaultSystem}.res or vmOutputs.packages.${defaultSystem}.vm-run;
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

  fallbackHost = {
    scan = {
      domains.homeEntries = [ ];
      themes = themesLib;
    };
    monitors = { };
    db = { };
    sshAgent = { };
    username = "user";
  };

  render = import ../render.nix {
    host = if representative != null then representative else fallbackHost;
    inherit lib;
  };

  mkHomeCfg =
    { host, hmModules, themeOverride ? null, shellOverride ? null }:
    mkHome {
      inherit
        self
        inputs
        host
        vmTool
        shellTool
        angstTool
        hmModules
        themeOverride
        shellOverride
        ;
      resTool = vmResTool;
    };

  mkHostFor =
    host:
    let
      p = profilesFor host;
    in
    mkHost {
      inherit self inputs host;
      hmModules = p.hm;
      nixosModules = p.nixos;
    };

  devshell = import ./devshell.nix {
    inherit pkgs inputs vmOutputs;
    host = representative;
    angstCli = angstTool;
  };

  mkChecks = import ../../checks/default.nix {
    inherit self inputs pkgs lib render;
    host = representative;
  };

  representativeHomes =
    if representative != null then
      let
        r = representative;
        p = profilesFor r;
        overrideTheme = builtins.head (
          builtins.filter (n: n != r.theme) (builtins.attrNames r.scan.themes.themes)
        );
      in
      {
        "${r.username}" = mkHomeCfg { host = r; hmModules = p.hm; };

        "${r.username}-theme-override-test" = mkHomeCfg {
          host = r;
          hmModules = p.hm;
          themeOverride = overrideTheme;
          shellOverride = "";
        };

        login-shell-valid = mkHomeCfg { host = r; hmModules = p.hm; shellOverride = "sh"; };

        login-shell-invalid = mkHomeCfg {
          host = r;
          hmModules = p.hm;
          shellOverride = "__angst_nonexistent_shell__";
        };
      }
    else
      { };
in
rec {
  nixosConfigurations = builtins.listToAttrs (
    map (host: {
      name = host.hostname;
      value = mkHostFor host;
    }) nixosHosts
  );

  homeConfigurations =
    builtins.listToAttrs (
      map (host: {
        name = host.hostname;
        value = mkHomeCfg {
          host = host;
          hmModules = (profilesFor host).hm;
        };
      }) hostList
    )
    // representativeHomes;

  packages.${defaultSystem} =
    let
      excludedNames = [
        "login-shell-valid"
        "login-shell-invalid"
        "${representative.username}-theme-override-test"
      ];
      hmPkgs = builtins.removeAttrs (
        builtins.mapAttrs (_: cfg: cfg.activationPackage) homeConfigurations
      ) excludedNames;
      extra =
        if representative != null then
          {
            default = homeConfigurations.${representative.username}.activationPackage;
            angst = angstTool;
            vm-cli = vmOutputs.packages.${defaultSystem}.wrapped;
            vm = vmOutputs.packages.${defaultSystem}.wrapped;
            vm-run = vmOutputs.packages.${defaultSystem}.vm-run;
            res = vmOutputs.packages.${defaultSystem}.res;
            shell = shellTool;
          }
        else
          { };
    in
    extra // hmPkgs;

  devShells.${defaultSystem} = devshell.shells;

  apps.${defaultSystem} =
    {
      vm = { type = "app"; program = "${vmOutputs.packages.${defaultSystem}.wrapped}/bin/vm"; };
      shell = { type = "app"; program = "${shellTool}/bin/shell"; };
      angst = { type = "app"; program = "${angstTool}/bin/angst"; };
      render = { type = "app"; program = "${pkgs.writeShellScript "angst-render" ''exec ${angstTool}/bin/angst render "$@"''}"; };
      watch = { type = "app"; program = "${pkgs.writeShellScript "angst-watch" ''exec ${angstTool}/bin/angst watch "$@"''}"; };
      check = { type = "app"; program = "${pkgs.writeShellScript "check" "set -euo pipefail; ${pkgs.nix}/bin/nix flake check --print-build-logs"}"; };
      lint-themes = { type = "app"; program = "${pkgs.writeShellScript "lint-themes" "set -euo pipefail; ${pkgs.nix}/bin/nix eval ${self}#lib.themeLint --raw"}"; };
      lint-desktop = { type = "app"; program = "${pkgs.writeShellScript "lint-desktop" ''set -euo pipefail; ${pkgs.nix}/bin/nix build ${self}#checks.${defaultSystem}.lint-desktop --no-link --print-build-logs; echo "All desktop config checks passed."''}"; };
      lint-shell = { type = "app"; program = "${pkgs.writeShellScript "lint-shell" ''set -euo pipefail; ${pkgs.nix}/bin/nix build ${self}#checks.${defaultSystem}.lint-shell --no-link --print-build-logs; echo "All shell config checks passed."''}"; };
      analyze = { type = "app"; program = "${pkgs.writeShellScript "analyze" ''exec python3 -m scripts.analyze_flake "$@"''}"; };
      analyze-to-file = { type = "app"; program = "${pkgs.writeShellScript "analyze-to-file" ''cd "$(git rev-parse --show-toplevel)" && exec python3 -m scripts.analyze_flake --output analysis.md "$@"''}"; };
    }
    // (
      if representative != null then
        {
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
        }
      else
        { }
    );

  checks.${defaultSystem} = mkChecks;

  formatter.${defaultSystem} = pkgs.nixfmt;

  lib = {
    inherit (render) renderDomainOutputsFor renderDomainOutputFor;
    themeLint =
      mkChecks.themeLint or (import ../../checks/theme {
        inherit lib themesLib;
        inherit (render) renderDomainOutputsFor;
      });
  };
}
