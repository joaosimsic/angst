{
  context,
}:

let
  inherit (context)
    lib
    themesLib
    pkgs
    mkChecks
    render
    defaultSystem
    ;
in
{
  checks.${defaultSystem} = mkChecks;

  formatter.${defaultSystem} = pkgs.writeShellScriptBin "nixfmt" ''
    if [ "$#" -eq 0 ]; then
      exec ${pkgs.findutils}/bin/find . -type f -name '*.nix' -not -path './.git/*' -exec ${pkgs.nixfmt}/bin/nixfmt {} +
    fi
    exec ${pkgs.nixfmt}/bin/nixfmt "$@"
  '';

  lib = {
    inherit (render) renderDomainOutputsFor renderDomainOutputFor renderProjectOutputs;
    themeLint =
      mkChecks.themeLint or (import ../../checks/theme {
        inherit lib themesLib;
        inherit (render) renderDomainOutputsFor;
      });
  };
}
