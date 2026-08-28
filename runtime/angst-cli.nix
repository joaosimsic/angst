{
  mkScript,
  pkgs,
  goAngst,
 ...
}:

mkScript {
  name = "angst";
  runtimeInputs = with pkgs; [
    nix
    age
    git
    openssh
    watchexec
    coreutils
    findutils
  ];
  text = ''
    exec ${goAngst}/bin/angst "$@"
  '';
}
