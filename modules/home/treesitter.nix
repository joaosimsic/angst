{
  config,
  lib,
  pkgs,
  ...
}:

let
  treesitter = import ../../lib/treesitter.nix {
    inherit lib pkgs;
    grammars = lib.unique config.toolchains.treesitterGrammars;
  };
in
{
  options.toolchains.treesitterGrammars = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Tree-sitter grammar packages";
  };

  options.toolchains.editor.lsp = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          command = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "LSP command and args";
          };
          extensions = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "File extensions for this LSP";
          };
          initialization = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            description = "Optional LSP initializationOptions";
          };
        };
      }
    );
    default = { };
    description = "Neutral LSP registry aggregated from toolchains";
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
