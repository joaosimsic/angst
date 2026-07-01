{
  self,
  pkgs,
  lib,
  themesLib,
  themeContext,
  themeLint,
  lintDesktop,
  lintShell,
  themeRenderedChecks,
  renderDomainOutputFor,
}:

let
  inherit (themeContext) hostTheme overrideTheme;

  themeSemanticDistinct = import ../checks/theme/semanticDistinct.nix {
    inherit lib pkgs themesLib;
    themeName = hostTheme;
  };

  themeOverrideCheck = import ../checks/theme/override.nix {
    inherit lib pkgs themesLib overrideTheme renderDomainOutputFor;
    homeConfiguration = self.homeConfigurations.joao-theme-override-test;
  };
in
{
  lint-themes = pkgs.writeText "lint-themes-check" themeLint;

  lint-desktop = lintDesktop;

  lint-shell = lintShell;

  theme-rendered = themeRenderedChecks;

  theme-override = themeOverrideCheck;

  home-theme-override-test =
    self.homeConfigurations.joao-theme-override-test.activationPackage;

  theme-semantic-distinct = themeSemanticDistinct;

  nixos-personal =
    self.nixosConfigurations.personal.config.system.build.toplevel;

  home-joao =
    self.homeConfigurations.joao.activationPackage;
}
