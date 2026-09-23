{
  lib,
  appimageTools,
  fetchurl,
}:

appimageTools.wrapType2 {
  pname = "paper-desktop";
  version = "0.5.11";
  src = fetchurl {
    url = "https://download.paper.design/linux/appImage";
    hash = "sha256-st9hMDQt6OMAzFPncTfqvu9rsS+Q689z5OX3rxaubzU=";
  };

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
}
