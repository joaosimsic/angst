{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      flake-utils,
    }:
    let
      eachSystem =
        rootFlake:
        flake-utils.lib.eachDefaultSystem (
          system:
          let
            overlays = [ (import rust-overlay) ];
            pkgs = import nixpkgs { inherit system overlays; };

            rustToolchain = pkgs.rust-bin.stable.latest.default.override {
              extensions = [
                "rust-src"
                "rust-analyzer"
                "cargo"
                "rustc"
              ];
            };

            rustPlatform = pkgs.makeRustPlatform {
              cargo = rustToolchain;
              rustc = rustToolchain;
            };

            defaultHost = "personal";

            vm-package = rustPlatform.buildRustPackage {
              pname = "vm";
              version = "0.1.0";
              src = ./.;
              cargoLock = {
                lockFile = ./Cargo.lock;
              };

              nativeBuildInputs = with pkgs; [
                pkg-config
                makeWrapper
              ];
              buildInputs = with pkgs; [ openssl ];

              postInstall = ''
                wrapProgram $out/bin/vm \
                  --prefix PATH : ${
                    pkgs.lib.makeBinPath [
                      pkgs.nix
                      pkgs.qemu
                      pkgs.openssh
                    ]
                  }
              '';

              meta = with pkgs.lib; {
                mainProgram = "vm";
              };
            };

            allHostVms = builtins.mapAttrs (hostname: configExpr: {
              toplevel = configExpr.config.specialisation.vm.configuration.system.build.toplevel;
              runner = configExpr.config.specialisation.vm.configuration.system.build.vm;
              scriptName = "run-${hostname}-vm";
            }) (rootFlake.nixosConfigurations or { });

            vm-run-script = pkgs.writeShellScriptBin "vm-run" ''
              TARGET_HOST="''${NIX_TARGET_HOST:-${defaultHost}}"
              KEY_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/vm/keys/$TARGET_HOST"
              KEY_FILE="$KEY_DIR/authorized_keys"

              NEW_ARGS=()
              for arg in "$@"; do
                if [ "$arg" = "--headless" ]; then
                  export QEMU_OPTS="''${QEMU_OPTS:-} -display none -vga none"
                else
                  NEW_ARGS+=("$arg")
                fi
              done

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
                echo "Error: no SSH public keys found in ssh-agent or ~/.ssh/*.pub for VM access."
                echo "Run ssh-add ~/.ssh/id_ed25519 or create a public key file before starting the VM."
                exit 1
              fi

              case "$TARGET_HOST" in
                ${pkgs.lib.concatStringsSep "\n" (
                  pkgs.lib.mapAttrsToList (hostname: paths: ''
                    "${hostname}")
                      export QEMU_NET_OPTS="hostfwd=tcp::2222-:22"
                      export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$PWD/$TARGET_HOST.qcow2}"
                      export SHARED_DIR="$KEY_DIR"
                      
                      exec ${paths.runner}/bin/${paths.scriptName} "''${NEW_ARGS[@]}"
                      ;;
                  '') allHostVms
                )}
                *)
                  echo "Error: Host profile '$TARGET_HOST' not found in your NixOS configurations."
                  exit 1
                  ;;
              esac
            '';

            res-script = pkgs.writeShellScriptBin "res" ''
              TARGET_HOST="''${NIX_TARGET_HOST:-''${NIX_DEFAULT_TARGET_HOST:-${defaultHost}}}"
              FLAKE_DIR="''${ANGST_REPO:-$PWD}"

              echo "Building VM for host '$TARGET_HOST' (cached after first build)..."
              nix build "path:$FLAKE_DIR#nixosConfigurations.$TARGET_HOST.config.specialisation.vm.configuration.system.build.vm" --no-link 2>&1 || true

              echo "Starting VM..."
              vm restart -l

              echo "Waiting for VM to be ready..."
              for i in $(seq 1 60); do
                if vm ssh "echo ready" 2>/dev/null; then
                  echo "VM is ready!"
                  break
                fi
                sleep 1
              done

              exec vm ssh
            '';

            vm-wrapped = pkgs.symlinkJoin {
              name = "vm-wrapped";
              paths = [ vm-package ];
              nativeBuildInputs = [ pkgs.makeWrapper ];
              postBuild = ''
                wrapProgram $out/bin/vm \
                  --prefix PATH : ${pkgs.lib.makeBinPath [ vm-run-script ]}
              '';
            };

          in
          {
              packages = {
              default = vm-package;
              vm = vm-package;

              wrapped = vm-wrapped;
              vm-run = vm-run-script;
              res = res-script;
            };

            devShells.default = pkgs.mkShell {
              name = "vm-shell";
              packages = [ vm-package ];
              nativeBuildInputs = [ rustToolchain ];
              buildInputs = with pkgs; [
                openssh
                pkg-config
                openssl
                qemu
              ];

              shellHook = ''
                export CARGO_BUILD_TARGET_DIR="$PWD/target"
                export VM_SSH_PORT="2222"
                export VM_SSH_USER="joao"

                export NIX_DEFAULT_TARGET_HOST="${defaultHost}"
                export NIX_VM_HOSTS_MAP='${builtins.toJSON allHostVms}'

                export PATH="${vm-run-script}/bin:$PATH"

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

                echo "VM Workspace Tool Active"
                echo "Target Host Variable: \$NIX_DEFAULT_TARGET_HOST"
              '';
            };
          }
        );
    in
    eachSystem self
    // {
      mkOutputs = eachSystem;
    };
}
