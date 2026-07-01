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

  domainRendererPaths = [
    ../../domains/terminal/ghostty/render.nix
    ../../domains/launcher/rofi/render.nix
    ../../domains/shell/nushell/render.nix
    ../../domains/editor/nvim/render.nix
    ../../domains/wm/i3/render.nix
    ../../domains/bar/i3status/render.nix
    ../../domains/shell/starship/render.nix
    ../../domains/terminal/zellij/render.nix
    ../../domains/files/yazi/render.nix
  ];

  renderDomainOutputsFor =
    hostName: themeName:
    let
      hostConfig = loadHost hostName;
      args = {
        inherit lib themesLib themeName hostConfig;
        fontFamily = fontsLib.defaultFamily;
        monitors = hostConfig.monitors or { };
      };
    in
    lib.concatLists (map (path: import path args) domainRendererPaths);

  renderDomainOutputPathsFor =
    hostName: themeName:
    lib.concatStringsSep "\n" (map (output: output.path) (renderDomainOutputsFor hostName themeName));

  renderDomainOutputFor =
    hostName: themeName: outputPath:
    let
      matches = lib.filter (output: output.path == outputPath) (renderDomainOutputsFor hostName themeName);
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
    inherit lib pkgs themesLib renderDomainOutputFor;
  };

  lintShell = import ../checks/shell.nix {
    inherit lib pkgs themesLib renderDomainOutputFor;
  };

  themeRenderedChecks = import ../checks/theme/rendered.nix {
    inherit lib pkgs themesLib renderDomainOutputFor;
    themeName = themeContext.hostTheme;
  };

  homeConfigurations = import ./homeConfigurations.nix {
    inherit lib hosts mkHome mkHomeWithExtraModules themeContext;
  };

  checks = import ./checks.nix {
    inherit self pkgs lib themesLib themeContext themeLint lintDesktop lintShell themeRenderedChecks renderDomainOutputFor;
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
      packages = [ pkgs.neovim pkgs.git angstCli ] ++ allToolchainPackages;
      shellHook = ''
        mkdir -p ~/.local/share/tree-sitter
        rm -rf ~/.local/share/tree-sitter/parser ~/.local/share/tree-sitter/queries 2>/dev/null
        ln -sf ${treesitterParsers} ~/.local/share/tree-sitter/parser
        ln -sf ${treesitterQueries} ~/.local/share/tree-sitter/queries
      '';
    };
  };

  angstCli = pkgs.writeShellApplication {
    name = "angst";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.nix
      pkgs.watchexec
      pkgs.jq
    ];
    text = ''
      usage() {
        cat <<'EOF'
      Usage:
        angst render [--repo PATH] [--host HOST] [--theme THEME] [--reload|--no-reload]
        angst watch  [--repo PATH] [--host HOST] [--theme THEME]
      EOF
      }

      repo_root_default() {
        if [ -n "''${ANGST_REPO:-}" ]; then
          printf '%s\n' "$ANGST_REPO"
        elif git rev-parse --show-toplevel >/dev/null 2>&1; then
          git rev-parse --show-toplevel
        else
          pwd
        fi
      }

      theme_default() {
        local repo_root="$1"
        local host_name="$2"
        if [ -n "''${ANGST_THEME:-}" ]; then
          printf '%s\n' "$ANGST_THEME"
        else
          # Fixed: Wrap with builtins.toString to clear string/derivation contexts that crash on dirty trees
          nix eval --impure --raw --expr "let host = import ''${repo_root}/hosts/''${host_name}; in builtins.toString (host.theme or \"monochrome\")"
        fi
      }

      reload_hooks() {
        if command -v i3-msg >/dev/null 2>&1 && [ -n "''${I3SOCK:-}" ]; then
          i3-msg reload >/dev/null || true
        fi
      }

      render_cmd() {
        local repo_root
        repo_root="$(repo_root_default)"
        local host_name="''${ANGST_HOST:-personal}"
        local theme_name=""
        local should_reload=1

        while [ "$#" -gt 0 ]; do
          case "$1" in
            --repo)
              repo_root="$2"
              shift 2
              ;;
            --host)
              host_name="$2"
              shift 2
              ;;
            --theme)
              theme_name="$2"
              shift 2
              ;;
            --reload)
              should_reload=1
              shift
              ;;
            --no-reload)
              should_reload=0
              shift
              ;;
            -h|--help)
              usage
              return 0
              ;;
            *)
              echo "unknown render option: $1" >&2
              usage >&2
              return 2
              ;;
          esac
        done

        if [ -z "$theme_name" ]; then
          theme_name="$(theme_default "$repo_root" "$host_name")"
        fi

        if [ ! -d "$repo_root/domains" ]; then
          echo "domains directory not found under $repo_root" >&2
          return 1
        fi

        echo "Evaluating templates in a single optimized batch..."
        local json_data
        json_data=$(nix eval --impure "$repo_root#lib.renderDomainOutputsFor" \
          --apply "f: builtins.toJSON (f \"$host_name\" \"$theme_name\")" --raw)

        while IFS= read -r path; do
            [ -n "$path" ] || continue
            local output="$repo_root/$path"
            mkdir -p "$(dirname "$output")"

            echo "$json_data" | jq -r ".[] | select(.path == \"$path\") | .text" > "$output"
            
            chmod u+w "$output"
            echo "rendered $path"
        done < <(echo "$json_data" | jq -r '.[] | .path')

        if [ "$should_reload" -eq 1 ]; then
          reload_hooks
        fi
      }

      watch_cmd() {
        local repo_root
        repo_root="$(repo_root_default)"
        local host_name="''${ANGST_HOST:-personal}"
        local theme_name="''${ANGST_THEME:-}"

        while [ "$#" -gt 0 ]; do
          case "$1" in
            --repo)
              repo_root="$2"
              shift 2
              ;;
            --host)
              host_name="$2"
              shift 2
              ;;
            --theme)
              theme_name="$2"
              shift 2
              ;;
            -h|--help)
              usage
              return 0
              ;;
            *)
              echo "unknown watch option: $1" >&2
              usage >&2
              return 2
              ;;
          esac
        done

        local args=(render --repo "$repo_root" --host "$host_name" --reload)
        if [ -n "$theme_name" ]; then
          args+=(--theme "$theme_name")
        fi

        watchexec \
          --watch "$repo_root/themes" \
          --watch "$repo_root/domains" \
          --watch "$repo_root/hosts/$host_name" \
          -- "$0" "''${args[@]}"
      }

      command="''${1:-}"
      if [ "$#" -gt 0 ]; then
        shift
      fi

      case "$command" in
        render)
          render_cmd "$@"
          ;;
        watch)
          watch_cmd "$@"
          ;;
        -h|--help|"")
          usage
          ;;
        *)
          echo "unknown command: $command" >&2
          usage >&2
          exit 2
          ;;
      esac
    '';
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
      vm     = vmOutputs.packages.${system}.vm;
      vm-run = vmOutputs.packages.${system}.vm-run;
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
