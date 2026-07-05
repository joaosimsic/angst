{ lib, pkgs, grammars }:

let
  treesitterParsers = pkgs.runCommand "treesitter-parsers" {} ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (grammar: let
      lang = lib.replaceStrings ["-"] ["_"] (lib.removePrefix "tree-sitter-" grammar.pname);
    in ''
      ln -s ${grammar}/parser $out/${lang}.so
    '') grammars}
  '';

  treesitterQueries = pkgs.runCommand "treesitter-queries" {} ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (grammar: let
      langBase = lib.removePrefix "tree-sitter-" grammar.pname;
      lang = lib.replaceStrings ["-"] ["_"] langBase;
    in ''
      if [ -d "${grammar.src}/queries" ]; then
        mkdir -p "$out/${lang}"
        cp -r ${grammar.src}/queries/* "$out/${lang}/"
      elif [ -d "${grammar}/queries" ]; then
        mkdir -p "$out/${lang}"
        cp -r ${grammar}/queries/* "$out/${lang}/"
      fi
    '') grammars}
  '';
in {
  inherit treesitterParsers treesitterQueries;
}
