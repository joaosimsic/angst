{ lib, pkgs, ... }:

let
  nixLibs = with pkgs; [
    stdenv.cc.cc
    libffi
    zlib
    zstd
  ];
  nixLdPath = lib.makeLibraryPath nixLibs;
in
{
  home.packages = [
    pkgs.nix-ld
    pkgs.xclip
    pkgs.xsel
    pkgs.wl-clipboard
  ] ++ nixLibs;

  home.sessionVariables = {
    LD_LIBRARY_PATH = lib.mkDefault "${nixLdPath}:\${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}";
    NIX_LD_LIBRARY_PATH = lib.mkDefault "${nixLdPath}:\${NIX_LD_LIBRARY_PATH:+:$NIX_LD_LIBRARY_PATH}";
    NIX_LD = lib.mkDefault "${pkgs.stdenv.cc.bintools.dynamicLinker}";
  };
}
