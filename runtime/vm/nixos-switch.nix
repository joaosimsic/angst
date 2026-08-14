{
  mkScript,
  pkgs,
}:

mkScript {
  name = "vm-nixos-switch";
  runtimeInputs = with pkgs; [
    nix
    coreutils
  ];
  text = ''
    if [ "$(id -u)" -ne 0 ]; then
      echo "vm-nixos-switch: must be run as root (sudo)." >&2
      exit 1
    fi

    flake_ref="''${1:-.}"

    sys="$(nix build --no-link --print-out-paths "$flake_ref#nixosConfigurations.vm.config.virtualisation.vmVariant.system.build.toplevel")"
    nix-env -p /nix/var/nix/profiles/system --set "$sys"
    exec "$sys/bin/switch-to-configuration" switch
  '';
}
