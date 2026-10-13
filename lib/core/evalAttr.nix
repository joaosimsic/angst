{ lib }:
let
  t = import "./types.nix" { inherit lib; };
in
{
  evalAttr =
    schema: raw:
    removeAttrs
      (lib.evalModules {
        modules = [
          {
            options.value = lib.mkOption { type = t.set schema; };
            config = raw;
          }
        ];
      }).config
      [ "_module" ];
}
