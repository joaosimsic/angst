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
      editor ? { },
    }:
    {
      home.packages = runtime ++ lsp ++ formatter ++ linter ++ tools ++ packageManager;
      toolchains.treesitterGrammars = treesitter;
      toolchains.editor.lsp = editor.lsp or { };
    };
in
{
  inherit mkToolchain;
}
