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

            shell-package = rustPlatform.buildRustPackage {
              pname = "shell";
              version = "0.1.0";
              src = ./.;
              cargoLock = {
                lockFile = ./Cargo.lock;
              };

              meta = with pkgs.lib; {
                mainProgram = "shell";
              };
            };

          in
          {
            packages = {
              default = shell-package;
            };

            devShells.default = pkgs.mkShell {
              name = "shell-shell";
              packages = [ shell-package ];
              nativeBuildInputs = [ rustToolchain ];
            };
          }
        );
    in
    eachSystem self
    // {
      mkOutputs = eachSystem;
    };
}
