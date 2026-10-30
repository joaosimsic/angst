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

  formatter.${defaultSystem} = pkgs.writeShellScriptBin "nixfmt" ''
    if [ "$#" -eq 0 ]; then
      exec ${pkgs.findutils}/bin/find . -type f -name '*.nix' -not -path './.git/*' -exec ${pkgs.nixfmt}/bin/nixfmt {} +
    fi
    exec ${pkgs.nixfmt}/bin/nixfmt "$@"
  '';

  lib = {
    inherit (render) renderDomainOutputsFor renderDomainOutputFor renderProjectOutputs;
    inherit (mkChecks) themeLint;
  };
}
