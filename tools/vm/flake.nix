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

            vm-run-script = pkgs.writeShellScriptBin "vm-run" ''
              TARGET_HOST="''${NIX_TARGET_HOST:-}"
              FLAKE_DIR="''${ANGST_REPO:-$PWD}"
              if [ -z "$TARGET_HOST" ] && [ -f "$FLAKE_DIR/local/config.nix" ]; then
                TARGET_HOST="$(nix eval --impure --expr "(import $FLAKE_DIR/local/config.nix).hostname" --raw 2>/dev/null)"
              fi
              TARGET_HOST="''${TARGET_HOST:-''${NIX_DEFAULT_TARGET_HOST:-''${ANGST_HOST:-${defaultHost}}}}"
              KEY_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/vm/keys/$TARGET_HOST"
              KEY_FILE="$KEY_DIR/authorized_keys"

              NEW_ARGS=()
              for arg in "$@"; do
                if [ "$arg" = "--headless" ]; then
                  export QEMU_OPTS="''${QEMU_OPTS:-} -display none"
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

              RUNNER="result/bin/run-''${TARGET_HOST}-vm"
              if [ ! -f "$RUNNER" ]; then
                RUNNER="result/bin/run-nixos-vm"
              fi
              if [ ! -f "$RUNNER" ]; then
                echo "Error: VM runner not found at result/bin/run-''${TARGET_HOST}-vm or result/bin/run-nixos-vm. Build the VM first (e.g. 'nix build .#nixosConfigurations.current.config.system.build.vm')."
                exit 1
              fi

              export ANGST_REPO="$PWD"
              export QEMU_NET_OPTS="hostfwd=tcp::2222-:22"
              export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$PWD/$TARGET_HOST.qcow2}"
              export SHARED_DIR="$KEY_DIR"

              exec "$RUNNER" "''${NEW_ARGS[@]}"
            '';

            res-script = pkgs.writeShellScriptBin "res" ''
              TARGET_HOST="''${NIX_TARGET_HOST:-}"
              FLAKE_DIR="''${ANGST_REPO:-$(pwd)}"
              if [ -z "$TARGET_HOST" ] && [ -f "$FLAKE_DIR/local/config.nix" ]; then
                TARGET_HOST="$(nix eval --impure --expr "(import $FLAKE_DIR/local/config.nix).hostname" --raw 2>/dev/null)"
              fi
              TARGET_HOST="''${TARGET_HOST:-''${NIX_DEFAULT_TARGET_HOST:-''${ANGST_HOST:-${defaultHost}}}}"
              SSH_PORT="''${VM_SSH_PORT:-2222}"

              SSH_USER="''${VM_SSH_USER:-}"
              if [ -z "$SSH_USER" ] && [ -f "$FLAKE_DIR/local/config.nix" ]; then
                SSH_USER="$(nix eval --impure --expr "(import $FLAKE_DIR/local/config.nix).username" --raw 2>/dev/null)"
              fi
              SSH_USER="''${SSH_USER:-''${ANGST_USERNAME:-}}"

              export ANGST_USERNAME="$SSH_USER"
              if [ -f "$FLAKE_DIR/local/config.nix" ]; then
                export ANGST_THEME="$(nix eval --impure --expr "(import $FLAKE_DIR/local/config.nix).theme or \"monochrome\"" --raw 2>/dev/null)"
                export ANGST_PASSWORD="$(nix eval --impure --expr "(import $FLAKE_DIR/local/config.nix).password" --raw 2>/dev/null)"
              fi

              echo "Building VM for host '$TARGET_HOST' (user: $SSH_USER)..."
              git -C "$FLAKE_DIR" update-index -q --refresh 2>/dev/null || true
              nix build ".#nixosConfigurations.current.config.system.build.vm" --impure --refresh --no-write-lock-file 2>&1

              RUNNER="result/bin/run-$TARGET_HOST-vm"
              if [ ! -f "$RUNNER" ]; then
                RUNNER="result/bin/run-nixos-vm"
              fi
              if [ ! -f "$RUNNER" ]; then
                echo "Error: VM runner not found at result/bin/run-$TARGET_HOST-vm or result/bin/run-nixos-vm"
                exit 1
              fi

              echo "Starting VM..."
              pkill -f "run-$TARGET_HOST-vm" 2>/dev/null || true
              pkill -f "qemu-system.*qcow2" 2>/dev/null || true
              rm -f "$HOME/.local/state/vm/vm.json" "$HOME/.local/state/vm/vm-mcp.json" 2>/dev/null || true
              sleep 2

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
                echo "Error: no SSH public keys found in ssh-agent or ~/.ssh/*.pub for VM access."
                exit 1
              fi

              export ANGST_REPO="$PWD"
              export QEMU_OPTS="-display none -vga none"
              export SHARED_DIR="$KEY_DIR"
              export QEMU_NET_OPTS="hostfwd=tcp::2222-:22"
              nohup "$RUNNER" > /tmp/vm-boot.log 2>&1 &

              SSH_OPTS="-p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=1 -o LogLevel=ERROR -o ForwardAgent=yes"
              echo "Waiting for VM to be ready..."
              for i in $(seq 1 60); do
                if ssh $SSH_OPTS "$SSH_USER@localhost" "echo ready" 2>/dev/null; then
                  echo "VM is ready!"
                  break
                fi
                sleep 1
              done

              ssh $SSH_OPTS -fNL 9093:localhost:9093 "$SSH_USER@localhost" 2>/dev/null && echo "Forwarding localhost:9093 to VM"

              exec ssh $SSH_OPTS "$SSH_USER@localhost"
            '';

            vm-wrapped = pkgs.symlinkJoin {
              name = "vm-wrapped";
              paths = [ vm-package ];
              nativeBuildInputs = [ pkgs.makeWrapper ];
              postBuild = ''
                wrapProgram $out/bin/vm \
                  --prefix PATH : ${pkgs.lib.makeBinPath [ vm-run-script ]} \
                  --set NIX_DEFAULT_TARGET_HOST "${defaultHost}"
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

                export NIX_DEFAULT_TARGET_HOST="${defaultHost}"

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
