{
  context,
}:

let
  inherit (context)
    homeConfigurations
    representative
    defaultSystem
    runtime
    vmOutputs
    shellTool
    hmSwitchTool
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
            angst = runtime.angstCli;
            vm-cli = vmOutputs.packages.${defaultSystem}.wrapped;
            vm = vmOutputs.packages.${defaultSystem}.wrapped;
            shell = shellTool;
          }
        else
          { };
    in
    { hm-switch = hmSwitchTool; } // extra // hmPkgs;
}
