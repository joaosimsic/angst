{
  lib,
  pkgs,
  userConfig,
  userEnv ? {},
  ...
}:

{
  system.stateVersion = "25.11";

  console.keyMap = lib.mkDefault "br-abnt2";

  services.xserver.xkb = {
    layout = lib.mkDefault "br";
    variant = lib.mkDefault "abnt2";
  };

  time.timeZone = lib.mkDefault "America/Sao_Paulo";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  networking.networkmanager.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  users.users.${userConfig.username} = {
    isNormalUser = true;
    description = userConfig.username;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
    ];
    initialPassword = lib.mkDefault "changeme";
    hashedPassword = let envPass = builtins.getEnv "ANGST_PASSWORD"; in
      lib.mkIf ((userEnv ? PASSWORD && userEnv.PASSWORD != "") || envPass != "")
      (if envPass != "" then envPass else userEnv.PASSWORD);
    shell = pkgs.nushell;
  };

  environment.shells = [
    pkgs.bash
    pkgs.nushell
  ];

  users.users.root.initialPassword = lib.mkDefault "changeme";

  programs.nix-ld.enable = true;
}
