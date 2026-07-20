{
  config,
  lib,
  pkgs,
  ...
}:

let
  treesitter = import ../../lib/treesitter.nix {
    inherit lib pkgs;
    grammars = config.toolchains.treesitterGrammars;
  };
in
{
  options.toolchains.treesitterGrammars = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Tree-sitter grammar packages";
  };

  config = {
    home.packages = [ pkgs.tree-sitter ];

    xdg.dataFile."tree-sitter/parser" = {
      source = treesitter.treesitterParsers;
      force = true;
    };
    xdg.dataFile."tree-sitter/queries" = {
      source = treesitter.treesitterQueries;
      force = true;
    };
  };
}
