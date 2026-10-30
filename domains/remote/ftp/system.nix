{
  config,
  lib,
  userConfig,
  ...
}:

let
  cfg = config.domains.remote.ftp;
in
{
  options.domains.remote.ftp = {
    enable = lib.mkEnableOption "FTP client with FUSE mount";
  };

  config = lib.mkIf cfg.enable {
    programs.fuse.userAllowOther = true;
    users.users.${userConfig.username}.extraGroups = [ "fuse" ];
  };
}
