{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.kernel.search;
in
{
  options.domains.kernel.search = {
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
