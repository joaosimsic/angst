{
  lib,
  appimageTools,
  curl,
  fetchurl,
  gnugrep,
  gnused,
  nix,
  writeShellApplication,
}:

let
  pname = "paper-desktop";
  version = "0.5.13";
  src = fetchurl {
    url = "https://download.paper.design/linux/appImage";
    hash = "sha256-RRxNXQ8NStBTNkUvD02BjyPSNt9hhKUftYRpW/Cg0vs=";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs =
    pkgs: with pkgs; [
      libsecret
      nss
      alsa-lib
      at-spi2-atk
      at-spi2-core
      cups
      dbus
      expat
      glib
      gtk3
      libdrm
      mesa
      nspr
      pango
      libX11
      libXcomposite
      libXdamage
      libXext
      libXfixes
      libXrandr
      libxcb
      libxkbcommon
      cairo
    ];

  meta = with lib; {
    description = "Paper Desktop – connected canvas (paper.design)";
    homepage = "https://paper.design";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    mainProgram = "paper-desktop";
  };

  passthru.updateScript = writeShellApplication {
    name = "update-paper-desktop";
    runtimeInputs = [
      curl
      gnugrep
      gnused
      nix
    ];
    text = ''
      set -euo pipefail
      cd "$(git rev-parse --show-toplevel)"
      target="domains/design/paper/package.nix"
      version="$(curl -sI https://download.paper.design/linux/appImage | grep -o 'filename="[^"]*"' | sed -E 's/.*paper-desktop-([0-9.]+)x86_64\.AppImage.*/\1/')"
      test -n "$version"
      hash="$(nix store prefetch-file --json https://download.paper.design/linux/appImage | sed -n 's/.*"hash": *"\([^"]*\)".*/\1/p')"
      test -n "$hash"
      sed -i -E "s/version = \"[0-9.]+\"/version = \"$version\"/" "$target"
      sed -i -E "s|hash = \"sha256-[^\"]*\"|hash = \"$hash\"|" "$target"
      echo "pinned paper-desktop $version $hash"
    '';
  };
}
