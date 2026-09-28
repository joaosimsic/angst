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
      pkgs.runCommand "rust-stable-1.95.0-wrappers" { } ''
        mkdir -p $out/bin
        for bin in cargo rustc rustdoc clippy-driver cargo-clippy cargo-fmt rustfmt rust-analyzer; do
          if [ -e ${stableToolchain}/bin/$bin ]; then
            ln -s ${stableToolchain}/bin/$bin $out/bin/$bin-stable
          fi
        done
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
