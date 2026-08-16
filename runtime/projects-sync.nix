{
  mkScript,
  pkgs,
  lib,
  goAngst,
}:
{
  projects,
  flakeSelf,
}:
mkScript {
  name = "angst-projects-sync";
  runtimeInputs = with pkgs; [
    git
    sops
    age
    openssh
  ];
  text = ''
    export ANGST_PROJECTS_STORE="$HOME/.secrets/projects"
    export ANGST_PROJECTS_REPO="${flakeSelf}/projects"
    export ANGST_PROJECTS_ONLY='${lib.concatStringsSep " " projects}'
    exec ${goAngst}/bin/angst projects "$@"
  '';
}