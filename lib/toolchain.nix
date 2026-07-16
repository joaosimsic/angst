_: 

let
  mkToolchain =
    {
      runtime ? [ ],
      lsp ? [ ],
      formatter ? [ ],
      linter ? [ ],
      tools ? [ ],
      packageManager ? [ ],
      treesitter ? [ ],
    }:
    {
      home.packages = runtime ++ lsp ++ formatter ++ linter ++ tools ++ packageManager;
      toolchains.treesitterGrammars = treesitter;
    };
in
{
  inherit mkToolchain;
}
