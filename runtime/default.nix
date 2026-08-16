{
  pkgs,
  lib,
  self,
}:

let
  mkScript =
    {
      name,
      text,
      runtimeInputs ? [ ],
      excludeShellChecks ? [ ],
      meta ? { },
    }:
    let
      drv = pkgs.writeShellApplication {
        inherit
          name
          text
          runtimeInputs
          excludeShellChecks
          ;
        meta = meta // {
          mainProgram = name;
        };
      };
    in
    drv // { bin = "${drv}/bin/${name}"; };

  loginShell = import ./login-shell.nix { inherit mkScript pkgs; };
  sshAddKeys = import ./ssh-add-keys.nix { inherit mkScript pkgs lib; };
  sshKeyProvision = import ./ssh-key-provision.nix { inherit mkScript pkgs; };
  bootstrapSecrets = import ./bootstrap-secrets.nix { inherit mkScript pkgs; };
  projectsSync = import ./projects-sync.nix { inherit mkScript pkgs lib; };
  ftpMount = import ./ftp-mount.nix { inherit mkScript pkgs; };
  ftpSecretsHome = import ./ftp-secrets-home.nix { inherit mkScript pkgs; };
  devshellHook = import ./devshell-hook.nix { inherit pkgs; };
  angstCli = import ./angst-cli.nix { inherit mkScript pkgs; };

  apps = {
    render = import ./apps/render.nix {
      inherit mkScript;
      inherit angstCli;
    };
    watch = import ./apps/watch.nix {
      inherit mkScript;
      inherit angstCli;
    };
    check = import ./apps/check.nix { inherit mkScript pkgs; };
    lint-themes = import ./apps/lint-themes.nix { inherit mkScript pkgs self; };
    lint-desktop = import ./apps/lint-desktop.nix { inherit mkScript pkgs self; };
    lint-shell = import ./apps/lint-shell.nix { inherit mkScript pkgs self; };
    analyze = import ./apps/analyze.nix { inherit mkScript pkgs; };
    analyze-to-file = import ./apps/analyze-to-file.nix { inherit mkScript pkgs; };
    ssh-deploy = import ./apps/ssh-deploy.nix { inherit mkScript pkgs self; };
  };

  vm = {
    homeManagerUpgrade = import ./vm/home-manager-upgrade.nix { inherit mkScript pkgs; };
    ephemeralSsh = import ./vm/ephemeral-ssh.nix { inherit mkScript pkgs; };
    ageKey = import ./vm/age-key.nix { inherit mkScript pkgs; };
    nixosSwitch = import ./vm/nixos-switch.nix { inherit mkScript pkgs; };
    homeSwitch = import ./vm/home-switch.nix { inherit mkScript pkgs; };
  };
in
{
  inherit
    mkScript
    loginShell
    sshAddKeys
    sshKeyProvision
    bootstrapSecrets
    projectsSync
    ftpMount
    ftpSecretsHome
    devshellHook
    angstCli
    apps
    vm
    ;
}
