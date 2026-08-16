{
  mkScript,
  pkgs,
  goAngst,
}:
{
  username,
  homeDirectory,
  injectWorkKey ? false,
}:
mkScript {
  name = "angst-vm-age-key";
  runtimeInputs = with pkgs; [
    coreutils
  ];
  text = ''
    exec ${goAngst}/bin/angst vm age-key --user "${username}" --home "${homeDirectory}"${if injectWorkKey then " --inject-work-key" else ""}
  '';
}