{
  config,
  lib,
  pkgs,
  userConfig,
  ...
}:

let
  cfg = config.domains.git.code;
  inherit (userConfig) username homeDirectory;
  projectsRoot = "${homeDirectory}/projects";

  ownershipScript = pkgs.writeShellScript "angst-git-ownership" ''
    set -eu
    root=${lib.escapeShellArg projectsRoot}
    [ -d "$root" ] || exit 0
    find "$root" -maxdepth 3 -type d -name .git -prune -print0 \
      | xargs -0 -r chown -R ${username}:users
  '';
in
{
  options.domains.git.code = {
    enable = lib.mkEnableOption "Git version control";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      git
    ];

    system.activationScripts.angstGitOwnership = lib.stringAfter [ "users" ] ''
      ${ownershipScript}
    '';

    systemd.services.angst-git-ownership = {
      description = "angst: ensure project git dirs are owned by ${username}";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = ownershipScript;
      };
    };
  };
}
