{
  mkScript,
  pkgs,
  lib,
}:
{ keys }:
mkScript {
  name = "ssh-add-keys";
  runtimeInputs = [
    pkgs.openssh
    pkgs.gnugrep
    pkgs.gawk
  ];
  excludeShellChecks = [ "SC2043" ];
  text = ''
    for key in ${toString (map lib.escapeShellArg keys)}; do
      [ -f "$key" ] || continue
      fp="$(ssh-keygen -lf "$key" | awk '{print $2}')"
      ssh-add -l 2>/dev/null | grep -q "$fp" && continue
      ssh-add "$key" 2>/dev/null || true
    done
  '';
}
