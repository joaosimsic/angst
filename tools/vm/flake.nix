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
      defaultHost = "vm";
      eachSystem =
        _rootFlake:
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

            vmRunnerScript =
              name: script:
              pkgs.writeShellScriptBin name (
                pkgs.lib.replaceStrings [ "@defaultHost@" ] [ defaultHost ] (
                  builtins.readFile ./scripts/lib/keys.sh + builtins.readFile script
                )
              );

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

            vm-run-script = vmRunnerScript "vm-run" ./scripts/vm-run.sh;

            res-script = vmRunnerScript "res" ./scripts/res.sh;

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
      defaultVmHost = defaultHost;
    };
}
