{
  lib,
  pkgs,
  userConfig,
  hostname ? "nixos",
  ...
}:

{
  options.angst.isQemuVm = lib.mkOption {
    internal = true;
    type = lib.types.bool;
    default = false;
    description = "Whether the system is a QEMU dev VM.";
  };

  config = {
    system.stateVersion = "25.11";

    console.keyMap = lib.mkDefault "br-abnt2";

    services.xserver.xkb = {
      layout = lib.mkDefault "br";
      variant = lib.mkDefault "abnt2";
    };

    time.timeZone = lib.mkDefault "America/Sao_Paulo";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    networking.networkmanager.enable = true;
    networking.hostName = lib.mkDefault hostname;

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nixpkgs.config = import ../../lib/nixpkgs-config.nix;

    users.users.${userConfig.username} = {
      isNormalUser = true;
      description = userConfig.username;
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "audio"
      ];
      shell = pkgs.nushell;
    };

    environment.shells = [
      pkgs.bash
      pkgs.nushell
    ];

    users.users.root.initialPassword = lib.mkDefault "changeme";

    programs.nix-ld.enable = true;
  };
}
