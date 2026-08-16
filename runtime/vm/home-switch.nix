{
  mkScript,
  pkgs,
}:

mkScript {
  name = "vm-home-switch";
  runtimeInputs = with pkgs; [
    nix
    coreutils
  ];
  text = ''
    flake_ref="''${1:-.}"

    gen="$(nix build --no-link --print-out-paths "$flake_ref#homeConfigurations.vm.activationPackage")"
    exec "$gen/activate" --driver-version 1
  '';
}
