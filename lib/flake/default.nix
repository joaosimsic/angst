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
}:

let
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
        homeDirectory = hostConfig.user.homeDirectory;
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
    inherit loadHost themesLib lib;
  };

  themeLint = import ../checks/theme {
    inherit lib themesLib renderDomainOutputsFor;
  };

  lintDesktop = import ../checks/desktop.nix {
    inherit
      lib
      pkgs
      themesLib
      renderDomainOutputFor
      ;
  };

  lintShell = import ../checks/shell.nix {
    inherit
      lib
      pkgs
      themesLib
      renderDomainOutputFor
      ;
  };

  themeRenderedChecks = import ../checks/theme/rendered.nix {
    inherit
      lib
      pkgs
      themesLib
      renderDomainOutputsFor
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
      ;
  };

  shared = import ./shared.nix {
    inherit pkgs lib shellOutputs vmOutputs system;
  };

  inherit (shared) allToolchainPackages treesitter angstCli shellWrapped;

  devShells = {
    safe = pkgs.mkShell {
      packages = [
        pkgs.neovim
        pkgs.git
      ]
      ++ allToolchainPackages;
      shellHook = ''
        mkdir -p ~/.local/share/tree-sitter
        rm -rf ~/.local/share/tree-sitter/parser ~/.local/share/tree-sitter/queries 2>/dev/null
        ln -sf ${treesitter.treesitterParsers} ~/.local/share/tree-sitter/parser
        ln -sf ${treesitter.treesitterQueries} ~/.local/share/tree-sitter/queries
      '';
    };

    dev = pkgs.mkShell {
      packages = [
        pkgs.neovim
        pkgs.git
        angstCli
      ]
      ++ allToolchainPackages
      ++ (with pkgs; [ openssh qemu cargo rustc rust-analyzer ])
      ++ [
        vmOutputs.packages.${system}.default
        vmOutputs.packages.${system}.vm-run
      ];
      shellHook = ''
        mkdir -p ~/.local/share/tree-sitter
        rm -rf ~/.local/share/tree-sitter/parser ~/.local/share/tree-sitter/queries 2>/dev/null
        ln -sf ${treesitter.treesitterParsers} ~/.local/share/tree-sitter/parser
        ln -sf ${treesitter.treesitterQueries} ~/.local/share/tree-sitter/queries
      '';
    };
  };
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
      default = self.homeConfigurations.joao.activationPackage;
      angst = angstCli;

      vm-cli = vmOutputs.packages.${system}.default;
      vm = vmOutputs.packages.${system}.vm;
      vm-run = vmOutputs.packages.${system}.vm-run;

      shell = shellWrapped;
    };
  };

  devShells = {
    ${system} = devShells // {
      vm = pkgs.mkShell {
        inputsFrom = [ vmOutputs.devShells.${system}.default ];
        packages = [ angstCli ];
      };
    };
  };

  apps = {
    ${system} = {
      vm = {
        type = "app";
        program = "${vmOutputs.packages.${system}.default}/bin/vm";
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

    };
  };
}
