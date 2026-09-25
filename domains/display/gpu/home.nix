{
  config,
  lib,
  pkgs,
  inputs,
  hostType,
  ...
}:

let
  cfg = config.domains.display.gpu;
in
{
  config = lib.mkIf (cfg.enable && hostType != "nixos") {
    targets.genericLinux.nixGL = {
      packages =
        let
          isIntelX86 = pkgs.stdenv.hostPlatform.isx86_64;
          patchedNixGL = builtins.toFile "nixGL-patched.nix" (
            builtins.replaceStrings
              [
                "kernel = null;"
                "nvidia_icd.x86_64.json"
                "nvidia_icd.i686.json"
              ]
              [
                ""
                "nvidia_icd.json"
                "nvidia_icd.json"
              ]
              (builtins.readFile "${inputs.nixGL.outPath}/nixGL.nix")
          );
        in
        pkgs.callPackage patchedNixGL (
          {
            nvidiaVersion = "470.256.02";
            nvidiaHash = "1pmi949s0gzzjw2w3qhhihb82gppd1icvdzk8w2bp5dnvri1hifn";
            nvidiaVersionFile = null;
            enable32bits = isIntelX86;
          }
          // lib.optionalAttrs (!isIntelX86) { intel-media-driver = null; }
        );
      defaultWrapper = "nvidia";
      installScripts = [ "nvidia" ];
      vulkan.enable = true;
    };
  };
}
