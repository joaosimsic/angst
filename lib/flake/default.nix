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
}:

let
  domainsPath = ../../domains;
  themesLib = import ../../themes/default.nix { inherit lib; };
  fontsLib = import ../home/fonts.nix;

  templateLib = import ../template/default.nix {
    inherit lib domainsPath themesLib fontsLib;
  };

  inherit (templateLib) renderTemplate renderTemplateFor;

  themeContext = import ../checks/theme/context.nix {
    inherit loadHost themesLib lib;
  };

  themeLint = import ../checks/theme {
    inherit lib themesLib domainsPath;
  };

  lintDesktop = import ../checks/desktop.nix {
    inherit lib pkgs themesLib renderTemplate domainsPath;
  };

  lintShell = import ../checks/shell.nix {
    inherit lib pkgs themesLib renderTemplate domainsPath;
  };

  themeRenderedChecks = import ../checks/theme/rendered.nix {
    inherit lib pkgs themesLib renderTemplateFor;
    themeName = themeContext.hostTheme;
  };

  homeConfigurations = import ./homeConfigurations.nix {
    inherit lib hosts mkHome mkHomeWithExtraModules themeContext;
  };

  checks = import ./checks.nix {
    inherit self pkgs lib themesLib themeContext themeLint lintDesktop lintShell themeRenderedChecks renderTemplateFor;
  };

  toolchainDir = ../../toolchains;
  toolchainFiles = builtins.attrNames (lib.filterAttrs
    (name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix")
    (builtins.readDir toolchainDir));

  evaluatedToolchains = map (f: import (toolchainDir + "/${f}") { inherit lib pkgs; }) toolchainFiles;

  allToolchainPackages = lib.unique (lib.concatMap (t: t.home.packages or []) evaluatedToolchains);
  allGrammars = lib.unique (lib.concatMap (t: t.toolchains.treesitterGrammars or []) evaluatedToolchains);

  treesitterParsers = pkgs.runCommand "treesitter-parsers" {} ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (grammar: let
      lang = lib.replaceStrings ["-"] ["_"] (lib.removePrefix "tree-sitter-" grammar.pname);
    in ''
      ln -s ${grammar}/parser $out/${lang}.so
    '') allGrammars}
  '';

  treesitterQueries = pkgs.runCommand "treesitter-queries" {} ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (grammar: let
      langBase = lib.removePrefix "tree-sitter-" grammar.pname;
      lang = lib.replaceStrings ["-"] ["_"] langBase;
    in ''
      if [ -d "${grammar.src}/queries" ]; then
        mkdir -p "$out/${lang}"
        cp -r ${grammar.src}/queries/* "$out/${lang}/"
      elif [ -d "${grammar}/queries" ]; then
        mkdir -p "$out/${lang}"
        cp -r ${grammar}/queries/* "$out/${lang}/"
      fi
    '') allGrammars}
  '';

  devShells = {
    nvim-test = pkgs.mkShell {
      packages = [ pkgs.neovim pkgs.git ] ++ allToolchainPackages;
      shellHook = ''
        mkdir -p ~/.local/share/tree-sitter
        rm -rf ~/.local/share/tree-sitter/parser ~/.local/share/tree-sitter/queries 2>/dev/null
        ln -sf ${treesitterParsers} ~/.local/share/tree-sitter/parser
        ln -sf ${treesitterQueries} ~/.local/share/tree-sitter/queries
      '';
    };
  };
in
{
  inherit themeLint lintDesktop lintShell themeRenderedChecks renderTemplateFor homeConfigurations;

  checks = {
    ${system} = checks;
  };

  packages = {
    ${system} = {
      default = self.homeConfigurations.joao.activationPackage;
      
      vm-cli = vmOutputs.packages.${system}.default;
      vm     = vmOutputs.packages.${system}.vm;
      vm-run = vmOutputs.packages.${system}.vm-run;
    };
  };

  devShells = {
    ${system} = devShells // {
      vm = vmOutputs.devShells.${system}.default;
    };
  };

  apps = {
    ${system} = {
      vm = {
        type = "app";
        program = "${vmOutputs.packages.${system}.default}/bin/vm";
      }; 

      check = {
        type = "app";
        program = "${pkgs.writeShellScript "check" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix flake check --print-build-logs
        ''}";
      };

      lint-themes = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-themes" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix eval ${self}#themeLint --raw
        ''}";
      };

      lint-desktop = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-desktop" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix build ${self}#checks.${system}.lint-desktop --no-link --print-build-logs
          echo "All desktop config checks passed."
        ''}";
      };

      lint-shell = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-shell" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix build ${self}#checks.${system}.lint-shell --no-link --print-build-logs
          echo "All shell config checks passed."
        ''}";
      };

      render-template = {
        type = "app";
        program = "${pkgs.writeShellScript "render-template" ''
          set -euo pipefail
          if [ "$#" -lt 2 ]; then
            echo "Usage: render-template <template-path> <theme>" >&2
            echo "Example: render-template terminal/ghostty/config/colors.conf monochrome" >&2
            exit 1
          fi
          ${pkgs.nix}/bin/nix eval ${self}#renderTemplateFor --apply "f: f \"$1\" \"$2\"" --raw
        ''}";
      };
    };
  };
}
