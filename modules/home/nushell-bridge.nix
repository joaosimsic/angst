{
  config,
  lib,
  pkgs,
  ...
}:

let
  sessionVars = config.home.sessionVariables;

  escapeNushellString = s: lib.escape [ "\"" "\\" ] s;

  genericVars = removeAttrs sessionVars [
    "LD_LIBRARY_PATH"
    "NIX_LD_LIBRARY_PATH"
    "NIX_LD"
  ];

  rawLd = sessionVars.LD_LIBRARY_PATH or "";
  nixLdPath = lib.head (lib.splitString ":\\\${" rawLd);

in
{
  xdg.configFile."nushell/hm-session-vars.nu".text = ''
    $env.LD_LIBRARY_PATH = if ($env.LD_LIBRARY_PATH? | is-empty) {
      "${nixLdPath}"
    } else {
      $"${nixLdPath}:($env.LD_LIBRARY_PATH)"
    }
    $env.NIX_LD_LIBRARY_PATH = if ($env.NIX_LD_LIBRARY_PATH? | is-empty) {
      "${nixLdPath}"
    } else {
      $"${nixLdPath}:($env.NIX_LD_LIBRARY_PATH)"
    }
    $env.NIX_LD = "${pkgs.stdenv.cc.bintools.dynamicLinker}"
    load-env {
      ${lib.concatStringsSep ",\n      " (
        lib.mapAttrsToList (n: v: ''${n}: "${escapeNushellString (toString v)}"'') genericVars
      )}
    }
  '';
}
