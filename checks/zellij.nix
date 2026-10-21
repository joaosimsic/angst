{
  pkgs,
  host,
  render,
}:

let
  actualConfig = render.renderDomainOutputFor host.theme "domains/terminal/zellij/config/config.kdl";
  actualConfigFile = pkgs.writeText "zellij-actual-config.kdl" actualConfig;
in
pkgs.runCommand "check-zellij-keybinds"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.python3
      pkgs.zellij
    ];
  }
  ''
    export HOME="$PWD/home"
    mkdir -p "$HOME"
    ${pkgs.zellij}/bin/zellij --config ${actualConfigFile} setup --check > setup-check.out
    grep -F 'CONFIG FILE]: Well defined.' setup-check.out
    python3 ${./zellij-keybinds.py} ${pkgs.zellij}/bin/zellij
    touch $out
  ''
