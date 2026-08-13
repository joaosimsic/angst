{
  config,
  lib,
  repoPath,
  flakeSelf,
  projects,
  runtime,
  ...
}:

let
  sync = runtime.projectsSync {
    inherit repoPath projects flakeSelf;
  };
in
{
  config = lib.mkIf config.domains.git.projects.enable {
    home.packages = [ sync ];

    home.activation.angstProjectsSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${sync.bin} sync || true
    '';

    systemd.user.services.angst-projects-sync = {
      Unit = {
        Description = "Sync declared dev projects";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${sync.bin} sync";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
