{ lib, ... }:

{
  options.domains.wm._i3.configLines = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    internal = true;
    description = "i3 config lines contributed by other domains";
  };
}
