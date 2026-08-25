{
  mkScript,
  pkgs,
  goAngst,
}:
mkScript {
  name = "analyze";
  runtimeInputs = with pkgs; [
    git
    deadnix
    statix
  ];
  text = ''
    exec ${goAngst}/bin/angst analyze "$@"
  '';
}
