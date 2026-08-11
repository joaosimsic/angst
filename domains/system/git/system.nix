{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.system.git;
in
{
  options.domains.system.git = {
    enable = lib.mkEnableOption "Git version control";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      git
    ];
  };
}
