{
  self,
  inputs,
  hostDefs,
  themeSys,
}:

let
  context = import ./context.nix {
    inherit
      self
      inputs
      hostDefs
      themeSys
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
  inherit (import ./tests.nix { inherit context; }) tests;
}
