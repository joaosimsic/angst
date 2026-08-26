{
  config,
  lib,
  userConfig,
  ...
}:

let
  cfg = config.domains.embedded.arduino;
in
{
  options.domains.embedded.arduino = {
    enable = lib.mkEnableOption "Arduino command-line interface";
  };

  config = lib.mkIf cfg.enable {
    users.users.${userConfig.username}.extraGroups = [
      "dialout"
      "uucp"
    ];

    services.udev.extraRules = ''

      SUBSYSTEM=="usb", ATTR{idVendor}=="2341", MODE="0666", GROUP="dialout"
      SUBSYSTEM=="usb", ATTR{idVendor}=="2a03", MODE="0666", GROUP="dialout"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", MODE="0666", GROUP="dialout"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="2a03", MODE="0666", GROUP="dialout"


      SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", MODE="0666", GROUP="dialout"


      SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE="0666", GROUP="dialout"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea70", MODE="0666", GROUP="dialout"
    '';
  };
}
