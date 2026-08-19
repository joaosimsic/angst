{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.embedded.arduino;
  homeDir = config.home.homeDirectory;
in
{
  config = lib.mkIf cfg.enable {
    home = {
      packages = [ pkgs.arduino-language-server ];

      file.".arduino15/arduino-cli.yaml" = {
        text = ''
          board_manager:
            additional_urls: []
          daemon:
            port: "127.0.0.1:50051"
          directories:
            data: ${homeDir}/.arduino15
            downloads: ${homeDir}/.arduino15/staging
            user: ${homeDir}/Arduino
          library:
            enable_unsafe_install: false
          logging:
            file: ""
            format: text
            level: info
          metrics:
            addr: ""
            enabled: true
          output:
            no_color: false
          sketch:
            always_export_binaries: false
          updater:
            enable_notification: true
        '';
      };

      activation.arduino-core-install = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${lib.getExe pkgs.arduino-cli} core update-index
        ${lib.getExe pkgs.arduino-cli} core install arduino:avr
      '';
    };
  };
}
