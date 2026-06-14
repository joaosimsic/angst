{ lib, pkgs, ... }:

{
  options.toolchains.treesitterGrammars = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = with pkgs.tree-sitter-grammars; [
      tree-sitter-markdown
      tree-sitter-markdown-inline
    ];
    description = "Tree-sitter grammar packages";
  };

  home.packages = [ pkgs.tree-sitter ];
}
