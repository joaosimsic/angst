{
  mkScript,
  pkgs,
  lib,
}:
{
  repoPath,
  projects,
  flakeSelf,
}:
mkScript {
  name = "angst-projects-sync";
  runtimeInputs = with pkgs; [
    git
    sops
    age
    jq
    openssl
    coreutils
    diffutils
    findutils
  ];
  text = builtins.concatStringsSep "\n" [
    (builtins.readFile (flakeSelf + "/runtime/angst-projects.sh"))
    ''
      set -euo pipefail
      export ANGST_PROJECTS_STORE="$HOME/${repoPath}/projects"
      export ANGST_PROJECTS_ONLY='${lib.concatStringsSep " " projects}'
      angst_projects_cmd "$@"
    ''
  ];
}
