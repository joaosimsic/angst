{
  pkgs,
  themesLib,
  host,
}:

let
  theme = import ../../domains/browser/firefox/theme.nix {
    inherit themesLib;
    config = {
      inherit (host) theme;
    };
  };

  userChrome = import ../../domains/browser/firefox/chrome.nix { inherit theme; };
  userContent = import ../../domains/browser/firefox/content.nix { inherit theme; };

  uc = pkgs.writeText "userChrome.css" userChrome;
  ucontent = pkgs.writeText "userContent.css" userContent;
in
{
  firefox-css =
    pkgs.runCommand "firefox-css-check"
      {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.gnugrep
        ];
      }
      ''
        set -e
        for f in ${uc} ${ucontent}; do
          if [ ! -s "$f" ]; then
            echo "firefox css: empty output at $f"
            exit 1
          fi
          opens=$(grep -o '{' "$f" | wc -l)
          closes=$(grep -o '}' "$f" | wc -l)
          if [ "$opens" -ne "$closes" ]; then
            echo "firefox css: unbalanced braces in $f (open=$opens close=$closes)"
            exit 1
          fi
        done
        touch $out
      '';
}
