{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.git.code;
in
{
  options.domains.git.code = {
    enable = lib.mkEnableOption "Git version control";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      git
    ];
  };
}
