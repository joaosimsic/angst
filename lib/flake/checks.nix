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

  formatter.${defaultSystem} = pkgs.nixfmt;

  lib = {
    inherit (render) renderDomainOutputsFor renderDomainOutputFor;
    themeLint =
      mkChecks.themeLint or (import ../../checks/theme {
        inherit lib themesLib;
        inherit (render) renderDomainOutputsFor;
      });
  };
}
