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
    systemd
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

  bevyLdPath = lib.makeLibraryPath bevyLibs;
  hostLdPath = "/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:/usr/local/lib:/usr/lib";
  rustRpath = "${pkgs.glibc}/lib:${pkgs.stdenv.cc.cc.lib}/lib";
in
{
  config = lib.mkIf config.domains.gamedev.env.enable {
    home.packages =
      with pkgs;
      [
        mold
        sccache
        pkg-config
      ]
      ++ bevyLibs;

    home.sessionVariables = {
      LD_LIBRARY_PATH = lib.mkForce "${bevyLdPath}:\${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}";
      NIX_LD_LIBRARY_PATH = lib.mkForce "${bevyLdPath}:\${NIX_LD_LIBRARY_PATH:+:$NIX_LD_LIBRARY_PATH}";
      NIX_LD = lib.mkForce "${pkgs.stdenv.cc.bintools.dynamicLinker}";
      PKG_CONFIG_PATH = lib.mkForce "${lib.makeSearchPath "lib/pkgconfig" bevyLibs}:${lib.makeSearchPath "share/pkgconfig" bevyLibs}:/usr/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig:\${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}";
      RUSTFLAGS = "-C link-arg=-fuse-ld=mold -C link-arg=-Wl,-rpath,${rustRpath}:${hostLdPath}";
      CARGO_BUILD_RUSTFLAGS = "-C link-arg=-fuse-ld=mold -C link-arg=-Wl,-rpath,${rustRpath}:${hostLdPath}";
      RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
      SCCACHE_DIR = "${config.home.homeDirectory}/.cache/sccache";
      SCCACHE_CACHE_SIZE = "10G";
      VK_ICD_FILENAMES = "${pkgs.mesa}/share/vulkan/icd.d/intel_icd.x86_64.json:${pkgs.mesa}/share/vulkan/icd.d/radeon_icd.x86_64.json:${pkgs.mesa}/share/vulkan/icd.d/intel_hasvk_icd.x86_64.json:${pkgs.mesa}/share/vulkan/icd.d/lvp_icd.x86_64.json:/usr/share/vulkan/icd.d/nvidia_icd.json:/usr/share/vulkan/icd.d/intel_icd.json";
    };
  };
}
