{
  mkScript,
  pkgs,
}:
mkScript {
  name = "analyze-to-file";
  runtimeInputs = [
    pkgs.python3
    pkgs.git
  ];
  text = ''
    cd "$(git rev-parse --show-toplevel)" && exec python3 -m tools.analyze_flake --output analysis.md "$@"
  '';
}
