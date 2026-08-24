{ lib, ... }:

{
  options.angst.healthcheck = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run per-domain health checks during home activation.";
    };
  };
}
