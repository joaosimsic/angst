{ config, lib, ... }:

let
  cfg = config.domains.terminal.tmux;
in
{
  config = lib.mkIf cfg.enable {
  };
}
