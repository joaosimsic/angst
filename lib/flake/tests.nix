{ context }:

let
  inherit (context)
    self
    pkgs
    lib
    runtime
    defaultSystem
    ;
in
{
  # Non-standard flake output: `nix flake check` ignores it, so the (slow,
  # KVM-backed) VM tests only run when explicitly built (CI).
  tests.${defaultSystem}.persist-ownership = import ../../checks/persist-ownership.nix {
    inherit
      self
      pkgs
      lib
      runtime
      ;
  };
}
