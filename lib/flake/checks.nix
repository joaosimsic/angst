{
  context,
}:

let
  inherit (context)
    lib
    themeSys
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
    inherit (render) renderDomainOutputsFor renderDomainOutputFor renderProjectOutputs;
    themeLint =
      mkChecks.themeLint or (import ../../systems/theme/tests {
        inherit lib themeSys;
        inherit (render) renderDomainOutputsFor;
      });
  };
}
