{
  lib,
  pkgs,
}:

let
  baseModule = {
    options.networking.hostName = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
    };
    options.assertions = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
    };
    options.warnings = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  mkGuard =
    hostname: acknowledge:
    (lib.evalModules {
      modules = [
        baseModule
        ../modules/nixos/generic-host.nix
        {
          config = {
            networking.hostName = hostname;
            angst.genericHost = {
              enable = true;
              acknowledgeDiskChanges = acknowledge;
            };
          };
        }
      ];
    }).config.assertions;

  good = mkGuard "generic" true;
  badHostname = mkGuard "not-generic" true;
  badAck = mkGuard "generic" false;

  allTrue = assertions: builtins.all (a: a.assertion) assertions;
in
if !(allTrue good) then
  throw "generic-host-guard: valid generic guard assertions failed"
else if allTrue badHostname then
  throw "generic-host-guard: non-generic hostname was accepted"
else if allTrue badAck then
  throw "generic-host-guard: missing acknowledgement was accepted"
else
  pkgs.runCommand "generic-host-guard" { } ''
    mkdir -p "$out"
    printf '%s\n' "generic host guard passed" >"$out/README"
  ''
