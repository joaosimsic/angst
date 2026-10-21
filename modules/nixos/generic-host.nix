{
  config,
  lib,
  ...
}:

let
  cfg = config.angst.genericHost;
in
{
  options.angst.genericHost = {
    enable = lib.mkEnableOption "generic btrfs provisioning host";
    acknowledgeDiskChanges = lib.mkEnableOption "acknowledge btrfs layout changes";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.networking.hostName == "generic";
        message = "angst.genericHost may only be enabled on hostname generic";
      }
      {
        assertion = cfg.acknowledgeDiskChanges;
        message = "generic host must explicitly acknowledge btrfs layout changes";
      }
    ];

    warnings = [
      "generic host: btrfs subvolumes may be created and the boot entry may change. GPT, ESP, and Windows partitions are not modified by generic-provision."
    ];
  };
}
