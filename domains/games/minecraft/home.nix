{ pkgs, ... }:
{
  home.packages = [
    (pkgs.prismlauncher.override {
      additionalLibs = with pkgs; [
        libXi
        libXrender
        libXtst
      ];
    })
  ];
}
