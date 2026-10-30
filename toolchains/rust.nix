{
  pkgs,
  lib,
  fenix ? null,
}:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;

  stableChannel = "1.95.0";
  stableSha256 = "sha256-gh/xTkxKHL4eiRXzWv8KP7vfjSk61Iq48x47BEDFgfk=";
  nightlyDate = "2026-09-27";
  nightlySha256 = "sha256-rXxcpk2Apcd3EIn3QauQyetdy8dmzoHyyQr4/ClbQMw=";

  stableComponents = [
    "cargo"
    "clippy"
    "rust-src"
    "rustc"
    "rustfmt"
    "rust-analyzer"
    "llvm-tools-preview"
  ];

  nightlyComponents = [
    "cargo"
    "clippy"
    "rust-src"
    "rustc"
    "rustfmt"
    "rust-analyzer"
    "llvm-tools-preview"
    "rustc-codegen-cranelift-preview"
  ];

  nightlyBase =
    if fenix == null then
      null
    else
      fenix.toolchainOf {
        channel = "nightly";
        date = nightlyDate;
        sha256 = nightlySha256;
      };

  stableBase =
    if fenix == null then
      null
    else
      fenix.toolchainOf {
        channel = stableChannel;
        sha256 = stableSha256;
      };

  nightlyToolchain =
    if nightlyBase == null then null else nightlyBase.withComponents nightlyComponents;

  stableToolchain = if stableBase == null then null else stableBase.withComponents stableComponents;

  stableWrappers =
    if stableToolchain == null then
      null
    else
      pkgs.runCommand "rust-stable-1.95.0-wrappers"
        {
          nativeBuildInputs = [ pkgs.makeWrapper ];
        }
        ''
          mkdir -p $out/bin
          makeWrapper ${stableToolchain}/bin/rustc $out/bin/rustc-stable --add-flags "--sysroot ${stableToolchain}"
          makeWrapper ${stableToolchain}/bin/rustdoc $out/bin/rustdoc-stable --add-flags "--sysroot ${stableToolchain}"
          makeWrapper ${stableToolchain}/bin/clippy-driver $out/bin/clippy-driver-stable --add-flags "--sysroot ${stableToolchain}"
          makeWrapper ${stableToolchain}/bin/cargo $out/bin/cargo-stable --set RUSTC ${stableToolchain}/bin/rustc
          if [ -e ${stableToolchain}/bin/cargo-clippy ]; then
            makeWrapper ${stableToolchain}/bin/cargo-clippy $out/bin/cargo-clippy-stable --set RUSTC ${stableToolchain}/bin/rustc
          fi
          if [ -e ${stableToolchain}/bin/cargo-fmt ]; then
            ln -s ${stableToolchain}/bin/cargo-fmt $out/bin/cargo-fmt-stable
          fi
          if [ -e ${stableToolchain}/bin/rustfmt ]; then
            ln -s ${stableToolchain}/bin/rustfmt $out/bin/rustfmt-stable
          fi
          if [ -e ${stableToolchain}/bin/rust-analyzer ]; then
            ln -s ${stableToolchain}/bin/rust-analyzer $out/bin/rust-analyzer-stable
          fi
          echo -n ${stableToolchain} > $out/stable-toolchain-path
        '';
in
if fenix == null then
  mkToolchain {
    runtime = with pkgs; [
      rustc
      cargo
    ];
    lsp = with pkgs; [ rust-analyzer ];
    formatter = with pkgs; [ rustfmt ];
    linter = with pkgs; [ clippy ];
    tools = with pkgs; [
      cargo-nextest
      cargo-watch
    ];
    treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-rust ];
    editor.lsp.rust = {
      command = [ "rust-analyzer" ];
      extensions = [ ".rs" ];
      initialization = {
        "rust-analyzer".check.command = "clippy";
        "rust-analyzer".inlayHints.chainingHints.enable = true;
        "rust-analyzer".inlayHints.parameterHints.enable = true;
        "rust-analyzer".inlayHints.typeHints.enable = true;
      };
    };
  }
else
  mkToolchain {
    runtime = [ nightlyToolchain ];
    tools =
      with pkgs;
      [
        cargo-nextest
        cargo-watch
      ]
      ++ lib.optionals (stableWrappers != null) [ stableWrappers ];
    treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-rust ];
    editor.lsp.rust = {
      command = [ "rust-analyzer" ];
      extensions = [ ".rs" ];
      initialization = {
        "rust-analyzer".check.command = "clippy";
        "rust-analyzer".inlayHints.chainingHints.enable = true;
        "rust-analyzer".inlayHints.parameterHints.enable = true;
        "rust-analyzer".inlayHints.typeHints.enable = true;
      };
    };
  }
