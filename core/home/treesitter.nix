{ config, lib, pkgs, ... }:

let
  treesitterParsers = pkgs.runCommand "treesitter-parsers" {} ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (grammar: let
      lang = lib.replaceStrings ["-"] ["_"] (lib.removePrefix "tree-sitter-" grammar.pname);
    in ''
      ln -s ${grammar}/parser $out/${lang}.so
    '') config.toolchains.treesitterGrammars}
  '';

  treesitterQueries = pkgs.runCommand "treesitter-queries" {} ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (grammar: let
      langBase = lib.removePrefix "tree-sitter-" grammar.pname;
      lang = lib.replaceStrings ["-"] ["_"] langBase;
    in ''
      # Check if queries exist in the upstream source repository
      if [ -d "${grammar.src}/queries" ]; then
        mkdir -p "$out/${lang}"
        cp -r ${grammar.src}/queries/* "$out/${lang}/"
      # Fallback if some nixpkgs derivations already moved them into $out
      elif [ -d "${grammar}/queries" ]; then
        mkdir -p "$out/${lang}"
        cp -r ${grammar}/queries/* "$out/${lang}/"
      fi
    '') config.toolchains.treesitterGrammars}
  '';
in
{
  options.toolchains.treesitterGrammars = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = with pkgs.tree-sitter-grammars; [
      tree-sitter-markdown
      tree-sitter-markdown-inline
    ];
    description = "Tree-sitter grammar packages";
  };

  config = {
    home.packages = [ pkgs.tree-sitter ];

    xdg.dataFile."tree-sitter/parser".source = treesitterParsers;
    xdg.dataFile."tree-sitter/queries".source = treesitterQueries;
  };
}
