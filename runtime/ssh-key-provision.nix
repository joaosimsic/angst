{
  mkScript,
  pkgs,
  goAngst,
}:
{
  username,
  homeDirectory,
  secretsDir,
}:
mkScript {
  name = "angst-provision-ssh-key";
  runtimeInputs = with pkgs; [
    coreutils
    age
    openssh
  ];
  text = ''
    exec ${goAngst}/bin/angst provision-ssh-key --user "${username}" --home "${homeDirectory}" --secrets-dir "${secretsDir}"
  '';
}
