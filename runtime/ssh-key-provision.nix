{
  mkScript,
  pkgs,
  goAngst,
}:
{
  username,
  homeDirectory,
  secretsDir,
  scopes ? [
    "personal"
    "work"
  ],
}:
mkScript {
  name = "angst-provision-ssh-key";
  runtimeInputs = with pkgs; [
    coreutils
    age
    openssh
  ];
  text = ''
    exec ${goAngst}/bin/angst provision-ssh-key --user "${username}" --home "${homeDirectory}" --secrets-dir "${secretsDir}" --scopes ${builtins.concatStringsSep "," scopes}
  '';
}
