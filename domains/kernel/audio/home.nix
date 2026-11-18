{
  config,
  lib,
  hostType,
  ...
}:

let
  cfg = config.domains.kernel.audio;
in
{
  config = lib.mkIf (cfg.enable && hostType != "nixos") {
    xdg.configFile."pipewire/pipewire.conf.d/10-angst-latency.conf".text = ''
      context.properties = {
        default.clock.quantum = 1024
        default.clock.min-quantum = 1024
        default.clock.max-quantum = 2048
      }
    '';
  };
}
