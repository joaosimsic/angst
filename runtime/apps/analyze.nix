{
  mkScript,
  pkgs,
}:
mkScript {
  name = "analyze";
  runtimeInputs = [ pkgs.python3 ];
  text = ''
    exec python3 -m tools.analyze_flake "$@"
  '';
}
