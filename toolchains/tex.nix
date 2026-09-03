{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [
    (texliveSmall.withPackages (ps: with ps; [
      scheme-small
      latexindent
      chktex
      latexmk
      abntex2
      enumitem
      lm
    ]))
  ];
  lsp = with pkgs; [ texlab ];
  formatter = [ ];
  linter = [ ];
  tools = with pkgs; [ biber ];
  treesitter = with pkgs.tree-sitter-grammars; [
    tree-sitter-latex
    tree-sitter-bibtex
  ];
}
