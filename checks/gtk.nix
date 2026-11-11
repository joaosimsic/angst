{
  pkgs,
}:

let
  gtk = import ../domains/dev/gtk/libs.nix { inherit pkgs; };
in
pkgs.runCommand "check-gtk"
  {
    nativeBuildInputs = [ pkgs.pkg-config ] ++ gtk.dev;
  }
  ''
    set -euo pipefail
    pkg-config --exists 'gtk4 >= 4.14'
    pkg-config --exists 'libadwaita-1 >= 1.5'
    echo "gtk4: $(pkg-config --modversion gtk4)"
    echo "libadwaita: $(pkg-config --modversion libadwaita-1)"
    touch $out
  ''
