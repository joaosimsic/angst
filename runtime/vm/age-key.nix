{
  mkScript,
  pkgs,
  goVm,
 ...
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
    exec ${goVm}/bin/vm age-key --user "${username}" --home "${homeDirectory}"${
      if injectWorkKey then " --inject-work-key" else ""
    }
  '';
}
