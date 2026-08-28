{
  config,
  lib,
  pkgs,
  flakeSelf,
  projects,
  runtime,
  ...
}:

let
  sync = runtime.projects-sync {
    inherit projects flakeSelf;
  };
in
{
  config = lib.mkIf config.domains.git.projects.enable {
    home.packages = [ sync ];

    home.activation.angstProjectsSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.secrets/projects"
      chmod 700 "$HOME/.secrets" 2>/dev/null || true
      ${sync.bin} import || true
      ${sync.bin} sync || true
    '';

    systemd.user.services.angst-projects-sync = {
      Unit = {
        Description = "Sync declared dev projects";
        After = [
          "network-online.target"
          "angst-provision-ssh-key.service"
        ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c '${sync.bin} import; ${sync.bin} sync'";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
