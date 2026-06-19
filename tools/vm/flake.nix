{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    
    root-flake = {
      url = "path:../../.";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, root-flake }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        };

        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };

        vm-package = rustPlatform.buildRustPackage {
          pname = "vm";
          version = "0.1.0";
          src = ./.;
          cargoLock = { lockFile = ./Cargo.lock; };
          nativeBuildInputs = with pkgs; [ pkg-config ];
          buildInputs = with pkgs; [ openssl ];
          meta = with pkgs.lib; { mainProgram = "vm"; };
        };

        defaultHost = "personal";

        allHostVms = builtins.mapAttrs (hostname: configExpr: {
          toplevel = configExpr.config.specialisation.vm.configuration.system.build.toplevel;
          runner   = configExpr.config.specialisation.vm.configuration.system.build.vm;
          scriptName = "run-${hostname}-vm";
        }) root-flake.nixosConfigurations;

      in
      {
        packages = {
          default = vm-package;
          vm = vm-package;

          vm-run = pkgs.writeShellScriptBin "vm-run" ''
            TARGET_HOST="''${NIX_TARGET_HOST:-${defaultHost}}"
            
            case "$TARGET_HOST" in
              ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (hostname: paths: ''
                "${hostname}")
                  export QEMU_NET_OPTS="hostfwd=tcp::2222-:22"
                  export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$PWD/$TARGET_HOST.qcow2}"
                  exec ${paths.runner}/bin/${paths.scriptName}
                  ;;
              '') allHostVms)}
              *)
                echo "Error: Host profile '$TARGET_HOST' not found in your NixOS configurations."
                exit 1
                ;;
            esac
          '';
        };

        devShells.default = pkgs.mkShell {
          name = "vm-shell";
          nativeBuildInputs = [ rustToolchain ];
          buildInputs = with pkgs; [ openssh pkg-config openssl qemu ];

          shellHook = ''
            export CARGO_BUILD_TARGET_DIR="$PWD/target"
            export VM_SSH_PORT="2222"
            export VM_SSH_USER="joao"
            
            export NIX_DEFAULT_TARGET_HOST="${defaultHost}"
            export NIX_VM_HOSTS_MAP='${builtins.toJSON allHostVms}'

            echo "VM Workspace Tool Active"
            echo "Target Host Variable: \$NIX_DEFAULT_TARGET_HOST"
          '';
        };
      }
    );
}
