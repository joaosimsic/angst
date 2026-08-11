{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.system.search;
in
{
  options.domains.system.search = {
    enable = lib.mkEnableOption "Search tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      fd
      ripgrep
      fzf
    ];
  };
}
