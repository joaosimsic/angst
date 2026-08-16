{
  mkScript,
  pkgs,
  goAngst,
}:
mkScript {
  name = "angst-vm-ephemeral-ssh";
  runtimeInputs = [ ];
  text = ''
    exec ${goAngst}/bin/angst vm ephemeral-ssh \
      --mountpoint-bin ${pkgs.util-linux}/bin/mountpoint \
      --mount-bin ${pkgs.util-linux}/bin/mount \
      --rm-bin ${pkgs.coreutils}/bin/rm \
      --cp-bin ${pkgs.coreutils}/bin/cp \
      --mkdir-bin ${pkgs.coreutils}/bin/mkdir
  '';
}