{
  config,
  lib,
  pkgs,
  ...
}:

let
  treesitter = import ../treesitter.nix {
    inherit lib pkgs;
    grammars = config.toolchains.treesitterGrammars;
  };
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

    xdg.dataFile."tree-sitter/parser".source = treesitter.treesitterParsers;
    xdg.dataFile."tree-sitter/queries".source = treesitter.treesitterQueries;
  };
}
