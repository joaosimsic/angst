{
  context,
}:

let
  inherit (context)
    pkgs
    mkChecks
    render
    defaultSystem
    ;
in
{
  checks.${defaultSystem} = removeAttrs mkChecks [ "themeLint" ];

  formatter.${defaultSystem} = pkgs.nixfmt;

  lib = {
    inherit (render) renderDomainOutputsFor renderDomainOutputFor renderProjectOutputs;
    inherit (mkChecks) themeLint;
  };
}
