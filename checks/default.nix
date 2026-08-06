{
  self,
  cfg,
  pkgs,
  lib,
  render,
  ...
}:

let
  inherit (lib) attrNames filter head;

  themesLib = cfg.scan.themes;
  alternate = head (filter (n: n != cfg.theme) (attrNames themesLib.themes));

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
    themeName = cfg.theme;
  };

  themeSemanticDistinct = import ./theme/semanticDistinct.nix {
    inherit lib pkgs;
    themesLib = cfg.scan.themes;
    themeName = cfg.theme;
  };

  themeOverrideCheck = import ./theme/override.nix {
    inherit lib pkgs themesLib;
    overrideTheme = alternate;
    inherit (render) renderDomainOutputFor;
    homeConfiguration = self.homeConfigurations."${cfg.username}-theme-override-test";
  };

  checkPassword = import ./password.nix {
    inherit lib pkgs cfg;
  };

  loginShell = import ./login-shell.nix {
    inherit self pkgs;
  };

  lintNix = import ./lint-nix.nix { inherit pkgs; };
in
{
  check-password = checkPassword;
  lint-nix = lintNix;
  lint-themes = pkgs.writeText "lint-themes-check" themeLint;
  lint-desktop = lintDesktop;
  lint-shell = lintShell;
  theme-rendered = themeRendered;
  theme-override = themeOverrideCheck;
  theme-semantic-distinct = themeSemanticDistinct;
  home-theme-override-test =
    self.homeConfigurations."${cfg.username}-theme-override-test".activationPackage;
  login-shell-valid = loginShell.valid;
  login-shell-invalid = loginShell.invalid;
}
