{
  self,
  inputs,
  hostDefs,
  themesLib,
}:

let
  context = import ./context.nix {
    inherit
      self
      inputs
      hostDefs
      themesLib
      ;
  };
in
{
  inherit (import ./configurations.nix { inherit context; })
    nixosConfigurations
    homeConfigurations
    devShells
    ;
  inherit (import ./packages.nix { inherit context; })
    packages
    ;
  inherit (import ./apps.nix { inherit context; })
    apps
    ;
  inherit (import ./checks.nix { inherit context; })
    checks
    formatter
    lib
    ;
}
