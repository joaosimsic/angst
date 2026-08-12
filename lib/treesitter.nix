{
  lib,
  pkgs,
  grammars,
}:

let
  treesitterParsers =
    pkgs.runCommand "treesitter-parsers"
      {
        nativeBuildInputs = [ pkgs.patchelf ];
      }
      ''
        mkdir -p $out
        ${lib.concatMapStringsSep "\n" (
          grammar:
          let
            lang = lib.replaceStrings [ "-" ] [ "_" ] (lib.removePrefix "tree-sitter-" grammar.pname);
          in
          ''
            cp ${grammar}/parser $out/${lang}.so
            chmod +w $out/${lang}.so
            patchelf --set-rpath ${pkgs.stdenv.cc.cc.lib}/lib $out/${lang}.so
          ''
        ) grammars}
      '';

  treesitterQueries = pkgs.runCommand "treesitter-queries" { } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (
      grammar:
      let
        langBase = lib.removePrefix "tree-sitter-" grammar.pname;
        lang = lib.replaceStrings [ "-" ] [ "_" ] langBase;
      in
      ''
        if [ -d "${grammar.src}/queries" ]; then
          mkdir -p "$out/${lang}"
          cp -r ${grammar.src}/queries/* "$out/${lang}/"
        elif [ -d "${grammar}/queries" ]; then
          mkdir -p "$out/${lang}"
          cp -r ${grammar}/queries/* "$out/${lang}/"
        fi
        # Some grammars (nvim-treesitter style) ship queries nested as
        # queries/<lang>/... instead of flat files. Flatten that level so
        # Neovim resolves queries/<lang>/<group>.scm for the parser.
        # compgen -G is robust to nullglob/failglob, unlike bare `ls path/*`.
        if [ -d "$out/${lang}/${lang}" ] && ! compgen -G "$out/${lang}/*.scm" >/dev/null; then
          cp -r "$out/${lang}/${lang}"/. "$out/${lang}/"
          chmod -R u+w "$out/${lang}/${lang}"
          rm -rf "$out/${lang}/${lang}"
        fi
      ''
    ) grammars}
    # Hard invariant: no grammar may ship queries nested as <lang>/<lang>.
    # Neovim resolves queries/<lang>/<group>.scm, so a leftover nested dir
    # means the flatten above silently failed. Fail the build if one remains.
    for d in "$out"/*/; do
      lang=$(basename "$d")
      if [ -d "$d/$lang" ]; then
        echo "ERROR: tree-sitter queries for '$lang' are nested under '$lang/$lang' (flatten failed)" >&2
        exit 1
      fi
    done
  '';
in
{
  inherit treesitterParsers treesitterQueries;
}
