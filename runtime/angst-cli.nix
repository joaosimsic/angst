{
  mkScript,
  pkgs,
  goAngst,
}:

mkScript {
  name = "angst";
  runtimeInputs = with pkgs; [
    nix
    sops
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
