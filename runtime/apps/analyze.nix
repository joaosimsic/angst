{
  mkScript,
  pkgs,
  goAnalyze,
}:
mkScript {
  name = "analyze";
  runtimeInputs = with pkgs; [
    git
    deadnix
    statix
  ];
  text = ''
    exec ${goAnalyze}/bin/analyze "$@"
  '';
}
