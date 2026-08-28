{
  mkScript,
  pkgs,
  goAnalyze,
}:
mkScript {
  name = "analyze-to-file";
  runtimeInputs = with pkgs; [
    git
    deadnix
    statix
  ];
  text = ''
    cd "$(git rev-parse --show-toplevel)" && exec ${goAnalyze}/bin/analyze --output analysis.md "$@"
  '';
}
