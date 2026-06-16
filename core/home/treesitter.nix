{ config, lib, pkgs, ... }:

let
  allGrammars = pkgs.tree-sitter.withPlugins (_: config.toolchains.treesitterGrammars);
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

    xdg.configFile."nvim/parser".source = "${allGrammars}/parser";
  }
}
