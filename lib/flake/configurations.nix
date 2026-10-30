{
  context,
}:

let
  inherit (context)
    nixosConfigurations
    homeConfigurations
    devshell
    defaultSystem
    ;
in
{
  inherit nixosConfigurations homeConfigurations;
  devShells.${defaultSystem} = devshell.shells;
}
