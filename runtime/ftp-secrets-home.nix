{
  mkScript,
  pkgs,
  goAngst,
 ...
}:
{
  homeDirectory,
  configs,
}:
mkScript {
  name = "angst-ftp-secrets-home";
  runtimeInputs = with pkgs; [
    age
    coreutils
  ];
  excludeShellChecks = [ "SC2086" ];
  text =
    let
      confArgs = builtins.concatStringsSep " " (map (c: "--conf ${c.source}:${c.dest}") configs);
    in
    ''
      exec ${goAngst}/bin/angst ftp decrypt --home "${homeDirectory}" ${confArgs}
    '';
}
