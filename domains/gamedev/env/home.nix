{
  config,
  lib,
  pkgs,
  ...
}:

let
  bevyLibs = with pkgs; [
    stdenv.cc.cc.lib
    libffi
    libcap
    zlib
    zstd
    wayland
    libxkbcommon
    alsa-lib
    libudev-zero
    libx11
    libxcursor
    libxi
    libxrandr
    libxinerama
    libxcb
    libxau
    libxdmcp
    freetype
    fontconfig
    libGL
    vulkan-loader
    mesa
  ];

  bevyBrpMcp = pkgs.callPackage ../bevy-brp-mcp.nix { };

  # Media libs share the Rust link closure on genericLinux hosts (ffmpeg for
  # cutscenes, pulseaudio for voice). Keep their store paths in RPATH and
  # pkg-config here so `dev.media` and `gamedev.env` compose instead of
  # clobbering each other (see mkDefault in dev/media/home.nix).
  mediaRuntimeLibs = [
    pkgs.ffmpeg
    pkgs.libpulseaudio
  ];
  mediaDevLibs = [
    pkgs.ffmpeg.dev
    pkgs.libpulseaudio.dev
  ];

  bevyLdPath = lib.makeLibraryPath bevyLibs;
  hostLdPath = "/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:/usr/local/lib:/usr/lib";
  # Full link-time RPATH: nix glibc + gcc + every bevy native lib + media
  # runtime + host system dirs. Shell-independent fallback lives in
  # ~/.cargo/config.toml below so plain `cargo build` works even when
  # CARGO_BUILD_RUSTFLAGS did not reach the shell (bash/opencode).
  fullRustRpath = "${pkgs.glibc}/lib:${pkgs.stdenv.cc.cc.lib}/lib:${bevyLdPath}:${lib.makeLibraryPath mediaRuntimeLibs}:${hostLdPath}";
  fullPkgConfig = "${lib.makeSearchPath "lib/pkgconfig" (bevyLibs ++ mediaDevLibs)}:${lib.makeSearchPath "share/pkgconfig" (bevyLibs ++ mediaDevLibs)}:/usr/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig";
  cargoRustflags = "-C link-arg=-fuse-ld=mold -C link-arg=-Wl,-rpath,${fullRustRpath}";
in
{
  config = lib.mkIf config.domains.gamedev.env.enable {
    systemd.user.sessionVariables = {
      PKG_CONFIG_PATH = fullPkgConfig;
      NIX_LD = "${pkgs.stdenv.cc.bintools.dynamicLinker}";
      NIX_LD_LIBRARY_PATH = bevyLdPath;
      CARGO_BUILD_RUSTFLAGS = cargoRustflags;
    };

    home.packages =
      with pkgs;
      [
        mold
        sccache
        pkg-config
        dioxus-cli
        git-lfs
        bevyBrpMcp
      ]
      ++ bevyLibs;

    home.sessionVariables = {
      NIX_LD_LIBRARY_PATH = lib.mkForce "${bevyLdPath}:\${NIX_LD_LIBRARY_PATH:+:$NIX_LD_LIBRARY_PATH}";
      NIX_LD = lib.mkForce "${pkgs.stdenv.cc.bintools.dynamicLinker}";
      PKG_CONFIG_PATH = lib.mkForce "${fullPkgConfig}:\${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}";
      CARGO_BUILD_RUSTFLAGS = cargoRustflags;
      RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
      SCCACHE_DIR = "${config.home.homeDirectory}/.cache/sccache";
      SCCACHE_CACHE_SIZE = "5G";
      VK_ICD_FILENAMES = "${pkgs.mesa}/share/vulkan/icd.d/intel_icd.x86_64.json:${pkgs.mesa}/share/vulkan/icd.d/radeon_icd.x86_64.json:${pkgs.mesa}/share/vulkan/icd.d/intel_hasvk_icd.x86_64.json:${pkgs.mesa}/share/vulkan/icd.d/lvp_icd.x86_64.json:/usr/share/vulkan/icd.d/nvidia_icd.json:/usr/share/vulkan/icd.d/intel_icd.json";
    };

    # Shell-independent fallback: same RPATH for shells that never sourced
    # hm-session-vars (bash, editors, opencode). dev/media skips its own
    # ~/.cargo/config.toml when gamedev.env is enabled so the two never fight.
    home.file.".cargo/config.toml".text = lib.mkForce ''
      [target.x86_64-unknown-linux-gnu]
      rustflags = [
        "-C",
        "link-arg=-Wl,-rpath,${fullRustRpath}",
      ]
    '';
  };
}
