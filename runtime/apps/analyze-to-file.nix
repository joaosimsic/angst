{
  mkScript,
  pkgs,
  goAngst,
}:
mkScript {
  name = "analyze-to-file";
  runtimeInputs = with pkgs; [
    git
    deadnix
    statix
  ];
  text = ''
    cd "$(git rev-parse --show-toplevel)" && exec ${goAngst}/bin/angst analyze --output analysis.md "$@"
  '';
}
