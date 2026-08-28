{
  lib,
  pkgs,
  render,
  host,
}:

let
  outputs = render.renderDomainOutputsFor host.theme;
  nuFiles = lib.filter (o: lib.hasPrefix "domains/shell/nushell/config/" o.path) outputs;
  files = map (o: {
    name = baseNameOf o.path;
    path = pkgs.writeText (baseNameOf o.path) o.text;
  }) nuFiles;
  dir = pkgs.linkFarm "nushell-configs" files;
in
{
  nushell-syntax =
    pkgs.runCommand "nushell-syntax-check"
      {
        nativeBuildInputs = [
          pkgs.nushell
          pkgs.bash
          pkgs.coreutils
          pkgs.gnugrep
        ];
      }
      ''
        set -e
        shopt -s nullglob
        for f in ${dir}/*.nu; do
          echo "nu --ide-check: $f"
          diag=$(nu --ide-check 100 "$f")
          if echo "$diag" | grep -q '"severity":"Error"'; then
            echo "nushell syntax error in $f:"
            echo "$diag"
            exit 1
          fi
        done
        touch $out
      '';
}
