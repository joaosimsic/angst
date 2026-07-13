{
  pkgs,
  lib,
  shellOutputs,
  vmOutputs,
  system,
  hostShellBinPaths ? "",
  defaultHost ? "generic",
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
      pkgs.mkpasswd
    ];
    text = builtins.readFile ../../scripts/angst.sh;
  };

  shellBin = shellOutputs.packages.${system}.default;

  safeBinPath = pkgs.lib.makeBinPath ([ pkgs.neovim pkgs.git ] ++ allToolchainPackages);

  
  
  vmRunShim = pkgs.writeShellScriptBin "vm-run" ''
    TARGET_HOST="''${NIX_TARGET_HOST:-''${NIX_DEFAULT_TARGET_HOST:-${defaultHost}}}"
    FLAKE_DIR="''${ANGST_REPO:-$PWD}"
    if [ -z "$TARGET_HOST" ] && [ -f "$FLAKE_DIR/user.env" ]; then
      ENV_HOST="$(grep "^HOST=" "$FLAKE_DIR/user.env" | tail -1 | cut -d= -f2-)"
      if [ -n "$ENV_HOST" ]; then
        TARGET_HOST="$ENV_HOST"
      fi
    fi
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

    export ANGST_REPO="''${ANGST_REPO:-$PWD}"
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

  
  
  
  
  resWrapper = pkgs.writeShellScriptBin "res" ''
    FLAKE_DIR="''${ANGST_REPO:-$(pwd)}"
    if [ -f "$FLAKE_DIR/user.env" ]; then
      export ANGST_USERNAME="$(grep "^USERNAME=" "$FLAKE_DIR/user.env" | tail -1 | cut -d= -f2-)"
      export ANGST_THEME="$(grep "^THEME=" "$FLAKE_DIR/user.env" | tail -1 | cut -d= -f2-)"
      export ANGST_HOST="$(grep "^HOST=" "$FLAKE_DIR/user.env" | tail -1 | cut -d= -f2-)"
      export ANGST_PASSWORD="$(grep "^PASSWORD=" "$FLAKE_DIR/user.env" | tail -1 | cut -d= -f2-)"
    fi
    exec nix run "path:$(pwd)#res" --impure --refresh -- "$@"
  '';

  devBinPath = pkgs.lib.makeBinPath (
    [ pkgs.neovim pkgs.git angstCli ]
    ++ allToolchainPackages
    ++ (with pkgs; [ openssh qemu cargo rustc rust-analyzer ])
    ++ [
      vmOutputs.packages.${system}.default
      resWrapper
      vmOutputs.packages.${system}.vm-run
    ]
  );

  shellDevHook = pkgs.writeText "shell-dev-hook" ''
    export VM_SSH_PORT=2222
    export NIX_DEFAULT_TARGET_HOST=${defaultHost}
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

    # res on PATH always evaluates fresh via nix run --impure --refresh
    res() { nix run "path:''${ANGST_REPO:-$PWD}#res" --impure --refresh -- "$@"; }
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
    shellWrapped
    shellDevHook
    devEntryScript
    ;
  shellTool = shellWrapped;
}
