{
  mkScript,
  pkgs,
  goAngst,
 ...
}:
{
  shell,
  homeDirectory,
  username,
}:
mkScript {
  name = "angst-set-login-shell";
  runtimeInputs = with pkgs; [
    coreutils
    gnugrep
    bash
  ];
  text = ''
    exec ${goAngst}/bin/angst login-shell --shell "${shell}" --home "${homeDirectory}" --user "${username}"
  '';
}
