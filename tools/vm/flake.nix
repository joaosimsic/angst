{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils }: {
    
    mkOutputs = rootFlake: flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "cargo" "rustc" ];
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
          cargoLock = { lockFile = ./Cargo.lock; };
          
          nativeBuildInputs = with pkgs; [ pkg-config makeWrapper ];
          buildInputs = with pkgs; [ openssl ];

          postInstall = ''
            wrapProgram $out/bin/vm \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nix pkgs.qemu pkgs.openssh ]}
          '';

          meta = with pkgs.lib; { mainProgram = "vm"; };
        };

        allHostVms = builtins.mapAttrs (hostname: configExpr: {
          toplevel = configExpr.config.specialisation.vm.configuration.system.build.toplevel;
          runner   = configExpr.config.specialisation.vm.configuration.system.build.vm;
          scriptName = "run-${hostname}-vm";
        }) rootFlake.nixosConfigurations; 

        vm-run-script = pkgs.writeShellScriptBin "vm-run" ''
          TARGET_HOST="''${NIX_TARGET_HOST:-${defaultHost}}"
          
          NEW_ARGS=()
          for arg in "$@"; do
            if [ "$arg" = "--headless" ]; then
              export QEMU_OPTS="''${QEMU_OPTS:-} -display none -vga none"
            else
              NEW_ARGS+=("$arg")
            fi
          done
          
          case "$TARGET_HOST" in
            ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (hostname: paths: ''
              "${hostname}")
                export QEMU_NET_OPTS="hostfwd=tcp::2222-:22"
                export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$PWD/$TARGET_HOST.qcow2}"
                
                exec ${paths.runner}/bin/${paths.scriptName} "''${NEW_ARGS[@]}"
                ;;
            '') allHostVms)}
            *)
              echo "Error: Host profile '$TARGET_HOST' not found in your NixOS configurations."
              exit 1
              ;;
          esac
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
        };

        devShells.default = pkgs.mkShell {
          name = "vm-shell";
          packages = [ vm-package ];
          nativeBuildInputs = [ rustToolchain ];
          buildInputs = with pkgs; [ openssh pkg-config openssl qemu ];

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
  };
}
