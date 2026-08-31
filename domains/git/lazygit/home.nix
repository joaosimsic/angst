{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !config.domains.git.lazygit.enable || config.domains.git.code.enable;
          message = "domains.git.lazygit requires domains.git.code to be enabled";
        }
      ];
    }
    (lib.mkIf config.domains.git.lazygit.enable {
      home.packages = [ pkgs.lazygit ];
    })
  ];
}
