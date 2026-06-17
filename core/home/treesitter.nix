{ config, lib, pkgs, ... }:

let
  nvimParsers = pkgs.runCommand "nvim-treesitter-parsers" {} ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (grammar: ''
      ln -s ${grammar}/parser $out/${lib.removePrefix "tree-sitter-" grammar.pname}.so
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

    xdg.configFile."nvim/parser".source = nvimParsers;
  };
}
