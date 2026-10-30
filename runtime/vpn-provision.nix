{
  mkScript,
  pkgs,
  goAngst,
}:
{
  secretsDir,
  destDir,
  username,
  homeDirectory,
  scopes ? [
    "personal"
    "work"
  ],
}:
mkScript {
  name = "angst-provision-vpn";
  runtimeInputs = with pkgs; [
    age
    coreutils
  ];
  text = ''
    exec ${goAngst}/bin/angst provision-vpn \
      --secrets-dir "${secretsDir}" \
      --dest-dir "${destDir}" \
      --user "${username}" \
      --home "${homeDirectory}" \
      --scopes ${builtins.concatStringsSep "," scopes}
  '';
}
