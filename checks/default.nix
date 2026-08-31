{
  self,
  host,
  pkgs,
  lib,
  render,
  hostList,
  runtime,
}:

let
  inherit (lib) attrNames filter head;

  themesLib = host.scan.themes;
  alternate = head (filter (n: n != host.theme) (attrNames themesLib.themes));

  themeLint = import ./theme {
    inherit lib themesLib;
    inherit (render) renderDomainOutputsFor;
  };

  lintDesktop = import ./desktop.nix {
    inherit lib pkgs themesLib;
    inherit (render) renderDomainOutputFor;
  };

  lintShell = import ./shell.nix {
    inherit lib pkgs themesLib;
    inherit (render) renderDomainOutputFor;
  };

  themeRendered = import ./theme/rendered.nix {
    inherit lib pkgs themesLib;
    inherit (render) renderDomainOutputsFor;
    themeName = host.theme;
  };

  themeSemanticDistinct = import ./theme/semanticDistinct.nix {
    inherit lib pkgs;
    themesLib = host.scan.themes;
    themeName = host.theme;
  };

  themeOverrideCheck = import ./theme/override.nix {
    inherit lib pkgs themesLib;
    overrideTheme = alternate;
    inherit (render) renderDomainOutputFor;
    homeConfiguration = self.homeConfigurations."${host.username}-theme-override-test";
  };

  checkPassword = import ./password.nix {
    inherit pkgs host;
  };

  loginShell = import ./login-shell.nix {
    inherit self pkgs;
  };

  lintNix = import ./lint-nix.nix { inherit pkgs; };

  checkSecretsEncrypted = import ./secrets.nix { inherit pkgs; };

  checkDeclared = import ./declared.nix {
    inherit pkgs lib hostList;
  };

  checkTreesitter = import ./treesitter.nix {
    inherit
      pkgs
      lib
      hostList
      self
      ;
  };

  checkProjectsPipeline = import ./projects-pipeline.nix {
    inherit pkgs runtime;
  };

  checkVaultPipeline = import ./vault-pipeline.nix {
    inherit pkgs runtime;
  };

  checkFtpPipeline = import ./ftp-pipeline.nix {
    inherit pkgs runtime;
  };

  secretScan = import ./secret-scan.nix { inherit pkgs; };

  secretScanHooks = import ./secret-scan-hooks.nix { inherit pkgs; };

  domainHealth = import ./health {
    inherit
      lib
      pkgs
      themesLib
      render
      host
      ;
  };

  excludedHomes = [
    "login-shell-valid"
    "login-shell-invalid"
  ];

  evalAllConfigs =
    let
      nixosToplevels = builtins.mapAttrs (
        _: c:
        builtins.baseNameOf (builtins.unsafeDiscardStringContext c.config.system.build.toplevel.drvPath)
      ) self.nixosConfigurations;
      homeActivations = builtins.mapAttrs (
        _: c: builtins.baseNameOf (builtins.unsafeDiscardStringContext c.activationPackage.drvPath)
      ) (builtins.removeAttrs self.homeConfigurations excludedHomes);
    in
    pkgs.writeText "eval-all-configs" (
      builtins.concatStringsSep "\n" (builtins.attrValues (nixosToplevels // homeActivations))
    );

  buildAllConfigs =
    let
      nixosDrvs = builtins.attrValues (
        builtins.mapAttrs (_: c: c.config.system.build.toplevel) self.nixosConfigurations
      );
      homeDrvs = builtins.attrValues (
        builtins.mapAttrs (_: c: c.activationPackage) (
          builtins.removeAttrs self.homeConfigurations excludedHomes
        )
      );
      allDrvs = nixosDrvs ++ homeDrvs;
    in
    pkgs.writeText "build-all-configs" (builtins.concatStringsSep "\n" (map (d: "${d}") allDrvs));
in
{
  check-password = checkPassword;
  check-secrets-encrypted = checkSecretsEncrypted.secrets;
  check-projects-encrypted = checkSecretsEncrypted.projects;
  check-ssh-keys = checkSecretsEncrypted.sshKeys;
  check-ftp-encrypted = checkSecretsEncrypted.ftp;
  check-vpn-encrypted = checkSecretsEncrypted.vpn;
  check-projects-ftp-declared = checkDeclared;
  check-projects-pipeline = checkProjectsPipeline;
  check-vault-pipeline = checkVaultPipeline;
  check-ftp-pipeline = checkFtpPipeline;
  secret-scan = secretScan;
  secret-scan-hooks = secretScanHooks;
  lint-nix = lintNix;
  check-treesitter = checkTreesitter;
  lint-themes = pkgs.writeText "lint-themes-check" themeLint;
  lint-desktop = lintDesktop;
  lint-shell = lintShell;
  theme-rendered = themeRendered;
  theme-override = themeOverrideCheck;
  theme-semantic-distinct = themeSemanticDistinct;
  home-theme-override-test =
    self.homeConfigurations."${host.username}-theme-override-test".activationPackage;
  login-shell-valid = loginShell.valid;
  login-shell-invalid = loginShell.invalid;
  eval-all = evalAllConfigs;
  build-all = buildAllConfigs;
}
// domainHealth
