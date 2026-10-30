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
  # Host system dirs so the standalone (non-gamedev) fallback also resolves
  # apt-provided libs at runtime on genericLinux.
  hostLdPath = "/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:/usr/local/lib:/usr/lib";
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
        # mkDefault so gamedev.env (mkForce) wins when both are enabled;
        # gamedev already bundles these media pkg-config paths.
        PKG_CONFIG_PATH = lib.mkDefault "${pkgConfigPath}:\${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}";
        C_INCLUDE_PATH = includePath;
        CPLUS_INCLUDE_PATH = includePath;
        LIBRARY_PATH = libPath;
      };

      # Standalone fallback only. When gamedev.env is enabled it owns
      # ~/.cargo/config.toml with the superset RPATH (bevy + media + host).
      file.".cargo/config.toml" = lib.mkIf (!config.domains.gamedev.env.enable) {
        text = ''
          [target.x86_64-unknown-linux-gnu]
          rustflags = [
            "-C",
            "link-arg=-Wl,-rpath,${rustRpath}:${hostLdPath}",
          ]
        '';
      };
    };
  };
}
