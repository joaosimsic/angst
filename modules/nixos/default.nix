{
  config,
  lib,
  pkgs,
  userConfig,
  hostname ? "nixos",
  ...
}:

let
  kbdParts = lib.splitString "-" config.angst.keyboardLayout;
  kbdLayout = lib.head kbdParts;
  kbdVariant = lib.optionalString (lib.length kbdParts > 1) (lib.elemAt kbdParts 1);
in
{
  imports = [
    ./font.nix
    (lib.mkAliasOptionModule [ "keyboardLayout" ] [ "angst" "keyboardLayout" ])
  ];

  options.angst.keyboardLayout = lib.mkOption {
    type = lib.types.str;
    default = "us";
  };

  config = {
    system.stateVersion = "25.11";

    console.keyMap = lib.mkDefault config.angst.keyboardLayout;

    services.xserver.xkb = {
      layout = lib.mkDefault kbdLayout;
      variant = lib.mkDefault kbdVariant;
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

    programs.nix-ld.enable = true;
  };
}
