{
  config,
  lib,
  pkgs,
  repoPath,
  flakeSelf,
  projects,
  ...
}:

let
  projectsSync = pkgs.writeShellApplication {
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
      (builtins.readFile (flakeSelf + "/scripts/angst-lib.sh"))
      (builtins.readFile (flakeSelf + "/scripts/angst-projects.sh"))
      ''
        set -euo pipefail
        export ANGST_PROJECTS_STORE="$HOME/${repoPath}/projects"
        export ANGST_PROJECTS_ONLY='${lib.concatStringsSep " " projects}'
        angst_projects_cmd "$@"
      ''
    ];
  };
in
{
  config = lib.mkIf config.domains.git.projects.enable {
    home.packages = [ projectsSync ];

    home.activation.angstProjectsSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${projectsSync}/bin/angst-projects-sync sync || true
    '';

    systemd.user.services.angst-projects-sync = {
      Unit = {
        Description = "Sync declared dev projects";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${projectsSync}/bin/angst-projects-sync sync";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
