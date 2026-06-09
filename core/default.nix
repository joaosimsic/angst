{ config, lib, pkgs, userConfig, ... }:

{
  system.stateVersion = "25.11"; 

  console.keyMap = lib.mkDefault "br-abnt2";

  services.xserver.xkb = {
    layout = lib.mkDefault "br";
    variant = lib.mkDefault "abnt2";
  };

  time.timeZone = lib.mkDefault "America/Sao_Paulo";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  users.users.${userConfig.username} = {
    isNormalUser = true;
    description = userConfig.username;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    initialPassword = lib.mkDefault "changeme";
    shell = pkgs.nushell;
  };

  environment.shells = [ pkgs.bash pkgs.nushell ];

  users.users.root.initialPassword = "changeme";

  programs.nix-ld.enable = true;
}
