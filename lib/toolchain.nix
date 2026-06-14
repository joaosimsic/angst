{ lib, pkgs }:

let
  mkToolchain = { runtime ? [], lsp ? [], formatter ? [], linter ? [], tools ? [], treesitter ? [] }:
    {
      home.packages = runtime ++ lsp ++ formatter ++ linter ++ tools;
      toolchains.treesitterGrammars = treesitter;
    };
in
{
  inherit mkToolchain;
}
