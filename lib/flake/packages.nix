{
  context,
}:

let
  inherit (context)
    homeConfigurations
    representative
    defaultSystem
    angstTool
    vmOutputs
    shellTool
    ;
in
{
  packages.${defaultSystem} =
    let
      excludedNames = [
        "login-shell-valid"
        "login-shell-invalid"
        "${representative.username}-theme-override-test"
      ];
      hmPkgs = builtins.removeAttrs (builtins.mapAttrs (
        _: cfg: cfg.activationPackage
      ) homeConfigurations) excludedNames;
      extra =
        if representative != null then
          {
            default = homeConfigurations.${representative.username}.activationPackage;
            angst = angstTool;
            vm-cli = vmOutputs.packages.${defaultSystem}.wrapped;
            vm = vmOutputs.packages.${defaultSystem}.wrapped;
            vm-run = vmOutputs.packages.${defaultSystem}.vm-run;
            res = vmOutputs.packages.${defaultSystem}.res;
            shell = shellTool;
          }
        else
          { };
    in
    extra // hmPkgs;
}
