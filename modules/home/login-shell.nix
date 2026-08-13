{
  config,
  lib,
  shell,
  runtime,
  ...
}:

let
  cfg = config.angst.loginShell;

  candidates = [
    "${config.home.homeDirectory}/.nix-profile/bin/${cfg.shell}"
    "/usr/local/bin/${cfg.shell}"
    "/usr/bin/${cfg.shell}"
    "/bin/${cfg.shell}"
  ];

  shellFound = lib.any (c: builtins.pathExists c) candidates;
in
{
  options.angst.loginShell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Sync the login shell on non-NixOS systems (adds to /etc/shells and chsh)";
    };

    shell = lib.mkOption {
      type = lib.types.str;
      default = shell;
      description = "Name of the shell to set as the login shell";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.shell != "") {
    assertions = [
      {
        assertion = shellFound;
        message = "angst: login shell '${cfg.shell}' not found (checked ${lib.concatStringsSep ", " candidates}). Install it via home packages or a system package.";
      }
    ];

    home.activation.setLoginShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      VERBOSE_ECHO="$VERBOSE_ECHO" DRY_RUN_CMD="$DRY_RUN_CMD" \
        ${(runtime.loginShell {
          inherit (cfg) shell;
          homeDirectory = config.home.homeDirectory;
          username = config.home.username;
        }).bin}
    '';
  };
}
