{
  mkScript,
  pkgs,
}:
mkScript {
  name = "generic-provision";
  runtimeInputs = with pkgs; [
    btrfs-progs
    coreutils
    findutils
    gawk
    git
    gnugrep
    nix
    nixos-rebuild
    rsync
    systemd
    util-linux
  ];
  text = builtins.readFile ./generic-provision.sh;
}
