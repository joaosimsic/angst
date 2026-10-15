{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.dev.ghidra.enable {
    home.packages = [
      pkgs.openjdk21
    ];

    home.sessionVariables = {
      GHIDRA_INSTALL_DIR = "${pkgs.ghidra-bin}/lib/ghidra";
      JAVA_HOME = "${pkgs.openjdk21.home}";
      GHIDRA_HEADLESS_MAXMEM = "4G";
    };
  };
}
