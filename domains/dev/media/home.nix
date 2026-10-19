{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) ffmpeg libpulseaudio;
  devLibs = [
    ffmpeg.dev
    libpulseaudio.dev
  ];
  pkgConfigPath = lib.makeSearchPath "lib/pkgconfig" devLibs;
  includePath = lib.makeSearchPath "include" devLibs;
  libPath = lib.makeSearchPath "lib" [
    ffmpeg.lib
    ffmpeg.dev
    libpulseaudio
    libpulseaudio.dev
  ];

  rustRpath = lib.makeLibraryPath [
    pkgs.glibc
    pkgs.stdenv.cc.cc.lib
    libpulseaudio
    ffmpeg
  ];
in
{
  config = lib.mkIf config.domains.dev.media.enable {
    home = {
      packages = [
        ffmpeg
        libpulseaudio
        pkgs.pkg-config
      ];

      sessionVariables = {
        PKG_CONFIG_PATH = lib.mkOverride 40 "${pkgConfigPath}:\${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}";
        C_INCLUDE_PATH = includePath;
        CPLUS_INCLUDE_PATH = includePath;
        LIBRARY_PATH = libPath;
      };

      file.".cargo/config.toml".text = ''
        [target.x86_64-unknown-linux-gnu]
        rustflags = [
          "-C",
          "link-arg=-Wl,-rpath,${rustRpath}",
        ]
      '';
    };
  };
}
