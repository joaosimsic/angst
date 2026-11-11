{
  config,
  lib,
  pkgs,
  ...
}:

let
  gtk = import ./libs.nix { inherit pkgs; };

  pkgConfigPath = lib.makeSearchPath "lib/pkgconfig" gtk.dev;
  hostLdPath = "/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:/usr/local/lib:/usr/lib";
  rustRpath = "${
    lib.makeLibraryPath (
      [
        pkgs.glibc
        pkgs.stdenv.cc.cc.lib
      ]
      ++ gtk.runtime
    )
  }:${hostLdPath}";

  # gamedev.env and dev.media already own these variables when enabled. Only
  # claim them on hosts where neither module composes the native dev closure.
  ownsEnv = !config.domains.gamedev.env.enable && !config.domains.dev.media.enable;
in
{
  config = lib.mkIf config.domains.dev.gtk.enable {
    home = {
      packages = [
        pkgs.pkg-config
      ]
      ++ gtk.runtime;

      sessionVariables = lib.mkIf ownsEnv {
        PKG_CONFIG_PATH = lib.mkDefault "${pkgConfigPath}:\${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}";
        CARGO_BUILD_RUSTFLAGS = lib.mkDefault "-C link-arg=-Wl,-rpath,${rustRpath}";
      };

      file.".cargo/config.toml" = lib.mkIf ownsEnv {
        text = ''
          [target.x86_64-unknown-linux-gnu]
          rustflags = [
            "-C",
            "link-arg=-Wl,-rpath,${rustRpath}",
          ]
        '';
      };
    };
  };
}
