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

  renderMonitorsFor =
    hostName:
    let
      hostConfig = loadHost hostName;
      monitors = hostConfig.monitors or { };
      monitorOrder = lib.unique (
        lib.filter (n: lib.hasAttr n monitors) (
          [ "primary" "secondary" ] ++ lib.attrNames monitors
        )
      );
      monitorLine =
        name:
        let
          m = monitors.${name};
        in
        "exec --no-startup-id xrandr --output ${m.name} --mode ${m.resolution} --rate ${toString m.refreshRate} --pos ${m.position}";
    in
    if monitors == { } then
      "# no monitor overrides configured"
    else
      lib.concatStringsSep "\n" (map monitorLine monitorOrder);

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

  angstCli = pkgs.writeShellApplication {
    name = "angst";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.nix
      pkgs.watchexec
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
          nix eval --impure --raw --expr "let host = import ''${repo_root}/hosts/''${host_name}; in host.theme or \"monochrome\""
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

        while IFS= read -r -d "" template; do
          local rel output template_rel
          rel="''${template#"$repo_root/domains/"}"
          output="''${template%.template}"
          template_rel="''${rel%.template}"
          mkdir -p "$(dirname "$output")"
          nix eval "$repo_root#lib.renderTemplateFor" --apply "f: f \"$template_rel\" \"$theme_name\"" --raw > "$output"
          chmod u+w "$output"
          echo "rendered $template_rel"
        done < <(find "$repo_root/domains" -path "*/config/*" -type f -name "*.template" -print0)

        if [ -d "$repo_root/domains/wm/i3/config" ]; then
          nix eval "$repo_root#lib.renderMonitorsFor" --apply "f: f \"$host_name\"" --raw > "$repo_root/domains/wm/i3/config/monitors.conf"
          chmod u+w "$repo_root/domains/wm/i3/config/monitors.conf"
          echo "rendered wm/i3/config/monitors.conf"
        fi

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
  inherit themeLint lintDesktop lintShell themeRenderedChecks renderTemplateFor renderMonitorsFor homeConfigurations;

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
      vm = vmOutputs.devShells.${system}.default;
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
          meta.description = "Render hot-reloadable configuration templates.";
        };

        watch = {
          type = "app";
          program = "${pkgs.writeShellScript "angst-watch" ''
            exec ${angstCli}/bin/angst watch "$@"
          ''}";
          meta.description = "Watch templates and themes, then render and reload.";
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
          meta.description = "Validate configuration template themes.";
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

        render-template = {
          type = "app";
          program = "${pkgs.writeShellScript "render-template" ''
            set -euo pipefail
            if [ "$#" -lt 2 ]; then
              echo "Usage: render-template <template-path> <theme>" >&2
              echo "Example: render-template terminal/ghostty/config/colors.conf monochrome" >&2
              exit 1
            fi
            ${pkgs.nix}/bin/nix eval ${self}#lib.renderTemplateFor --apply "f: f \"$1\" \"$2\"" --raw
          ''}";
          meta.description = "Render structural environment templates with target configuration profiles.";
        };
      };
    };
    
}
