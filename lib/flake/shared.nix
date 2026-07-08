{
  pkgs,
  lib,
  shellOutputs,
  vmOutputs,
  system,
  hostShellBinPaths ? "",
}:

let
  toolchainDir = ../../toolchains;
  toolchainFiles = builtins.attrNames (
    lib.filterAttrs (
      name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
    ) (builtins.readDir toolchainDir)
  );

  evaluatedToolchains = map (f: import (toolchainDir + "/${f}") { inherit lib pkgs; }) toolchainFiles;

  allToolchainPackages = lib.unique (lib.concatMap (t: t.home.packages or [ ]) evaluatedToolchains);
  allGrammars = lib.unique (
    lib.concatMap (t: t.toolchains.treesitterGrammars or [ ]) evaluatedToolchains
  );

  treesitter = import ../treesitter.nix {
    inherit lib pkgs;
    grammars = allGrammars;
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

  shellBin = shellOutputs.packages.${system}.default;

  safeBinPath = pkgs.lib.makeBinPath ([ pkgs.neovim pkgs.git ] ++ allToolchainPackages);

  # Lightweight vm-run shim that defers host resolution to runtime via nix,
  # avoiding the allHostVms → nixosConfigurations evaluation recursion.
  vmRunShim = pkgs.writeShellScriptBin "vm-run" ''
    TARGET_HOST="''${NIX_TARGET_HOST:-''${NIX_DEFAULT_TARGET_HOST:-personal}}"
    KEY_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/vm/keys/$TARGET_HOST"
    KEY_FILE="$KEY_DIR/authorized_keys"

    mkdir -p "$KEY_DIR"

    TMP_KEYS="$(mktemp)"
    trap 'rm -f "$TMP_KEYS"' EXIT

    if ssh-add -L > /dev/null 2>&1; then
      ssh-add -L >> "$TMP_KEYS"
    fi

    for pubkey in "$HOME"/.ssh/*.pub; do
      if [ -r "$pubkey" ]; then
        cat "$pubkey" >> "$TMP_KEYS"
      fi
    done

    awk '/^(ssh-rsa|ssh-ed25519|ecdsa-sha2-|sk-ssh-|sk-ecdsa-)/ { print }' "$TMP_KEYS" | sort -u > "$KEY_FILE"
    chmod 600 "$KEY_FILE"

    if [ ! -s "$KEY_FILE" ]; then
      echo "Error: no SSH public keys found in ssh-agent or ~/.ssh/*.pub for VM access." >&2
      echo "Run ssh-add ~/.ssh/id_ed25519 or create a public key file before starting the VM." >&2
      exit 1
    fi

    HEADLESS=0
    NEW_ARGS=()
    for arg in "$@"; do
      if [ "$arg" = "--headless" ]; then
        HEADLESS=1
      else
        NEW_ARGS+=("$arg")
      fi
    done

    if [ "$HEADLESS" -eq 1 ]; then
      export QEMU_OPTS="''${QEMU_OPTS:-} -display none -vga none"
    fi

    FLAKE_DIR="''${ANGST_REPO:-$PWD}"
    export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$PWD/$TARGET_HOST.qcow2}"
    export SHARED_DIR="$KEY_DIR"
    export QEMU_NET_OPTS="hostfwd=tcp::2222-:22"

    exec nix run "path:$FLAKE_DIR#nixosConfigurations.$TARGET_HOST.config.specialisation.vm.configuration.system.build.vm" -- "''${NEW_ARGS[@]}"
  '';

  devBinPath = pkgs.lib.makeBinPath (
    [ pkgs.neovim pkgs.git angstCli ]
    ++ allToolchainPackages
    ++ (with pkgs; [ openssh qemu cargo rustc rust-analyzer ])
    ++ [
      vmOutputs.packages.${system}.default
      vmOutputs.packages.${system}.res
      vmRunShim
    ]
  );

  shellDevHook = pkgs.writeText "shell-dev-hook" ''
    export VM_SSH_PORT=2222
    export VM_SSH_USER=joao
    export NIX_DEFAULT_TARGET_HOST=personal
    export CARGO_BUILD_TARGET_DIR="$PWD/target"

    if [ -z "$SSH_AUTH_SOCK" ]; then
      echo "Initializing local shell-bound SSH Agent..."
      eval $(ssh-agent -s) > /dev/null
      trap "ssh-agent -k > /dev/null" EXIT
    fi

    if [ -f "$HOME/.ssh/id_ed25519" ]; then
      ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null
    elif [ -f "$HOME/.ssh/id_rsa" ]; then
      ssh-add "$HOME/.ssh/id_rsa" 2>/dev/null
    fi

    # res available as a command on PATH via devBinPath
  '';

  devEntryScript = pkgs.writeShellScript "shell-dev-entry" ''
    . ${shellDevHook}
    exec "$ORIGINAL_SHELL"
  '';

  shellWrapped = pkgs.symlinkJoin {
    name = "shell-wrapped";
    paths = [ shellBin ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/shell \
        --set SHELL_SAFE_PATH "${safeBinPath}" \
        --set SHELL_DEV_PATH "${devBinPath}" \
        --set SHELL_DEV_ENTRY "${devEntryScript}" \
        --set SHELL_TS_PARSERS "${treesitter.treesitterParsers}" \
        --set SHELL_TS_QUERIES "${treesitter.treesitterQueries}" \
        ${lib.optionalString (hostShellBinPaths != "") "--set SHELL_ENABLED_SHELLS \"${hostShellBinPaths}\""}
    '';
  };
in
{
  inherit
    allToolchainPackages
    allGrammars
    treesitter
    angstCli
    safeBinPath
    devBinPath
    vmRunShim
    shellWrapped
    shellDevHook
    devEntryScript
    ;
  shellTool = shellWrapped;
}
