{
  self,
  system,
  pkgs,
  lib,
  hosts,
  loadHost,
  mkHome,
  mkHomeWithExtraModules,
  vmOutputs,
  shellOutputs,
  hostShellBinPaths,
}:

let
  testHostname = builtins.head hosts;

  parseEnvFile = import ../parseEnv.nix { inherit lib; };
  envPath = ../../user.env;
  pwd = builtins.getEnv "PWD";
  pwdEnvPath = if pwd != "" then pwd + "/user.env" else "";
  homeEnvPath = builtins.getEnv "HOME" + "/proj/angst/user.env";
  userEnv = let
    fromFile = if builtins.pathExists envPath then parseEnvFile envPath
      else if builtins.pathExists homeEnvPath then parseEnvFile homeEnvPath
      else if pwdEnvPath != "" && builtins.pathExists pwdEnvPath then parseEnvFile pwdEnvPath
      else { };
  in fromFile // (
    let h = builtins.getEnv "ANGST_HOST"; u = builtins.getEnv "ANGST_USERNAME"; in
    (if h != "" then { HOST = h; } else {}) // (if u != "" then { USERNAME = u; } else {})
  );
  envHost = userEnv.HOST or testHostname;
  envUsername = userEnv.USERNAME or (loadHost testHostname).user.username;

  domainsLib = import ../domains/default.nix {
    inherit lib;
    domainsPath = ../../domains;
  };
  themesLib = import ../../themes/default.nix { inherit lib; };
  fontsLib = import ../home/fonts.nix;

  domainRendererPaths = map (e: "${e.path}/render.nix") (
    lib.filter (e: e.hasRender or false) domainsLib.homeEntries
  );

  renderDomainOutputsFor =
    hostName: themeName:
    let
      hostConfig = loadHost hostName;
      checkHelpers = import ../../lib/checks/theme/assertions.nix {
        inherit lib;
        inherit themeName;
        theme = themesLib.get themeName;
      };
      args = {
        inherit
          lib
          themesLib
          themeName
          hostConfig
          checkHelpers
          ;
        fontFamily = fontsLib.defaultFamily;
        monitors = hostConfig.monitors or { };
        homeDirectory = "/home/${envUsername}";
      };
    in
    lib.concatLists (map (path: import path args) domainRendererPaths);

  renderDomainOutputPathsFor =
    hostName: themeName:
    lib.concatStringsSep "\n" (map (output: output.path) (renderDomainOutputsFor hostName themeName));

  renderDomainOutputFor =
    hostName: themeName: outputPath:
    let
      matches = lib.filter (output: output.path == outputPath) (
        renderDomainOutputsFor hostName themeName
      );
    in
    if matches == [ ] then
      builtins.throw "Unknown domain render output: ${outputPath}"
    else
      (builtins.head matches).text;

  themeContext = import ../checks/theme/context.nix {
    inherit loadHost themesLib lib testHostname;
  };

  themeLint = import ../checks/theme {
    inherit lib themesLib renderDomainOutputsFor testHostname;
  };

  lintDesktop = import ../checks/desktop.nix {
    inherit
      lib
      pkgs
      themesLib
      renderDomainOutputFor
      testHostname
      ;
  };

  lintShell = import ../checks/shell.nix {
    inherit
      lib
      pkgs
      themesLib
      renderDomainOutputFor
      testHostname
      ;
  };

  themeRenderedChecks = import ../checks/theme/rendered.nix {
    inherit
      lib
      pkgs
      themesLib
      renderDomainOutputsFor
      testHostname
      ;
    themeName = themeContext.hostTheme;
  };

  homeConfigurations = import ./homeConfigurations.nix {
    inherit
      lib
      hosts
      loadHost
      mkHome
      mkHomeWithExtraModules
      themeContext
      ;
  };

  checks = import ./checks.nix {
    inherit
      self
      pkgs
      lib
      themesLib
      themeContext
      themeLint
      lintDesktop
      lintShell
      themeRenderedChecks
      renderDomainOutputFor
      testHostname
      loadHost
      ;
  };

  shared = import ./shared.nix {
    inherit pkgs lib shellOutputs vmOutputs system hostShellBinPaths;
  };

  inherit (shared) allToolchainPackages treesitter angstCli shellWrapped shellDevHook;

  treesitterShellHook = ''
    mkdir -p ~/.local/share/tree-sitter
    rm -rf ~/.local/share/tree-sitter/parser ~/.local/share/tree-sitter/queries 2>/dev/null
    ln -sf ${treesitter.treesitterParsers} ~/.local/share/tree-sitter/parser
    ln -sf ${treesitter.treesitterQueries} ~/.local/share/tree-sitter/queries
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH
  '';

  fullDevPackages = [
    pkgs.neovim
    pkgs.git
    angstCli
  ]
  ++ allToolchainPackages
  ++ (with pkgs; [ openssh qemu cargo rustc rust-analyzer ])
  ++ [
    vmOutputs.packages.${system}.wrapped
    vmOutputs.packages.${system}.vm-run
    vmOutputs.packages.${system}.res
  ];

  devShells = {
    safe = pkgs.mkShell {
      packages = [
        pkgs.neovim
        pkgs.git
      ]
      ++ allToolchainPackages;
      shellHook = treesitterShellHook;
    };

    dev = pkgs.mkShell {
      packages = fullDevPackages;
      shellHook = ''
        ${treesitterShellHook}
        . ${shellDevHook}
      '';
    };
  };
  firstHostUser = (loadHost testHostname).user.username;
in
{
  inherit
    themeLint
    lintDesktop
    lintShell
    themeRenderedChecks
    renderDomainOutputsFor
    renderDomainOutputPathsFor
    renderDomainOutputFor
    homeConfigurations
    ;

  checks = {
    ${system} = checks;
  };

  packages = {
    ${system} = {
      default = self.homeConfigurations."${envUsername}@${envHost}".activationPackage;
      angst = angstCli;

      vm-cli = vmOutputs.packages.${system}.wrapped;
      vm = vmOutputs.packages.${system}.wrapped;
      vm-run = vmOutputs.packages.${system}.vm-run;
      res = vmOutputs.packages.${system}.res;

      shell = shellWrapped;
    };
  };

  devShells = {
    ${system} = devShells // {
      vm = pkgs.mkShell {
        inputsFrom = [ vmOutputs.devShells.${system}.default ];
        packages = fullDevPackages;
        shellHook = ''
          ${treesitterShellHook}
          . ${shellDevHook}
        '';
      };
    };
  };

  apps = {
    ${system} = {
      vm = {
        type = "app";
        program = "${vmOutputs.packages.${system}.wrapped}/bin/vm";
        meta.description = "Run a test virtual machine environment.";
      };

      shell = {
        type = "app";
        program = "${shellWrapped}/bin/shell";
        meta.description = "Enter a controlled Nix dev shell (dev or safe).";
      };

      angst = {
        type = "app";
        program = "${angstCli}/bin/angst";
        meta.description = "Render and watch hot-reloadable desktop configuration.";
      };

      render = {
        type = "app";
        program = "${pkgs.writeShellScript "angst-render" ''
          exec ${angstCli}/bin/angst render "$@"
        ''}";
        meta.description = "Render hot-reloadable domain configuration.";
      };

      watch = {
        type = "app";
        program = "${pkgs.writeShellScript "angst-watch" ''
          exec ${angstCli}/bin/angst watch "$@"
        ''}";
        meta.description = "Watch domain configs and themes, then render and reload.";
      };

      check = {
        type = "app";
        program = "${pkgs.writeShellScript "check" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix flake check --print-build-logs
        ''}";
        meta.description = "Run all internal sanity checks and evaluation evaluations.";
      };

      lint-themes = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-themes" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix eval ${self}#lib.themeLint --raw
        ''}";
        meta.description = "Validate domain theme renderers.";
      };

      lint-desktop = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-desktop" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix build ${self}#checks.${system}.lint-desktop --no-link --print-build-logs
          echo "All desktop config checks passed."
        ''}";
        meta.description = "Lint system window manager and desktop configurations.";
      };

      lint-shell = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-shell" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix build ${self}#checks.${system}.lint-shell --no-link --print-build-logs
          echo "All shell config checks passed."
        ''}";
        meta.description = "Lint shell script configuration profiles.";
      };

      ssh =
        let
          sshHostUser = envUsername;
        in
        {
          type = "app";
          program = "${pkgs.writeShellScript "angst-ssh-deploy" ''
            set -euo pipefail
            echo "==> Building & activating ${sshHostUser}@${envHost}..."
            nix build ${self}#homeConfigurations.${sshHostUser}@${envHost}.activationPackage --print-build-logs
            echo "==> Activating..."
            ./result/activate
            echo "==> Cleaning old Nix store..."
            nix-collect-garbage -d
            nix store gc
            echo "==> Done."
          ''}";
          meta.description = "Deploy ${envHost} host config and prune old Nix store entries.";
        };

    };
  };
}
