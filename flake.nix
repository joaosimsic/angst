{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
  let
    hosts = import ./lib/scanHosts.nix inputs;

    env = {
      inherit inputs;

      loadHost = hostname: import (./hosts + "/${hostname}");
    };

    homeLib = import ./lib/mkHome.nix env;
    mkHost = import ./lib/mkHost.nix (env // { mkHomeProfile = homeLib.mkHomeProfile; });
    inherit (homeLib) mkHome mkHomeWithExtraModules;

    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    lib = pkgs.lib;
    themesLib = import ./themes/default.nix { inherit lib; };
    fontsLib = import ./lib/fonts.nix;
    templateTokens = import ./lib/templateTokens.nix;
    domainsPath = ./domains;
    renderTemplate = import ./lib/renderTemplate.nix;

    resolveTemplatePath =
      relPath:
      let
        clean = lib.removePrefix "/" relPath;
        withSuffix = "${domainsPath}/${clean}.template";
        asPath = "${domainsPath}/${clean}";
      in
      if builtins.pathExists withSuffix then
        withSuffix
      else if lib.hasSuffix ".template" clean && builtins.pathExists asPath then
        asPath
      else
        builtins.throw "Template not found: ${clean} (tried ${withSuffix})";

    renderTemplateFor =
      templateRel: themeName:
      renderTemplate {
        inherit lib;
        templatePath = resolveTemplatePath templateRel;
        tokens = templateTokens {
          inherit themesLib;
          theme = themeName;
          fontFamily = fontsLib.defaultFamily;
        };
      };

    themeLint = import ./lib/lintThemes.nix {
      inherit lib themesLib domainsPath;
    };

    lintDesktop = import ./lib/lintDesktop.nix {
      inherit lib pkgs themesLib renderTemplate domainsPath;
    };

    lintShell = import ./lib/lintShell.nix {
      inherit lib pkgs themesLib renderTemplate domainsPath;
    };

    themeRenderedChecks = import ./lib/themeRenderedChecks.nix {
      inherit lib pkgs themesLib renderTemplateFor;
    };
  in
  {
    inherit themeLint lintDesktop lintShell themeRenderedChecks renderTemplateFor;

    nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost;

    homeConfigurations =
      let
        perHost = nixpkgs.lib.genAttrs
          (map (h: "joao@${h}") hosts)
          (name: mkHome (nixpkgs.lib.removePrefix "joao@" name));

        themeOverrideTest = mkHomeWithExtraModules "personal" [
          { theme = "catppuccin-mocha"; }
        ];
      in
      perHost // {
        joao = mkHome "personal";
        joao-theme-override-test = themeOverrideTest;
      };

    checks.${system} = {
      lint-themes = pkgs.writeText "lint-themes-check" themeLint;

      lint-desktop = lintDesktop;

      lint-shell = lintShell;

      theme-rendered = themeRenderedChecks;

      theme-override =
        let
          hm = self.homeConfigurations.joao-theme-override-test;
          theme = hm.config.theme;
          ghosttyColors = hm.config.xdg.configFile."ghostty/colors.conf".text;
        in
        if theme != "catppuccin-mocha" then
          throw "expected config.theme = catppuccin-mocha, got ${theme}"
        else if !(lib.hasInfix "background           = 1e1e2e" ghosttyColors) then
          throw "theme override did not reach rendered ghostty colors (expected catppuccin-mocha BG)"
        else
          pkgs.writeText "theme-override-check" "ok";

      home-catppuccin-mocha =
        self.homeConfigurations.joao-theme-override-test.activationPackage;

      theme-semantic-distinct =
        let
          theme = themesLib.get "catppuccin-mocha";
          roles = [
            "ERROR"
            "SUCCESS"
            "WARNING"
            "INFO"
            "COMMENT"
            "MUTED"
          ];
          values = map (role: theme.${role}) roles;
          uniqueValues = lib.unique values;
        in
        if lib.length values != lib.length uniqueValues then
          throw "catppuccin-mocha semantic roles must be distinct hues (got duplicates among ${lib.concatStringsSep ", " roles})"
        else
          pkgs.writeText "theme-semantic-distinct-check" "ok";
    };

    packages.${system} = {
      default = self.homeConfigurations.joao.activationPackage;
    };

    apps.${system} = {
      lint-themes = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-themes" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix eval ${self}#themeLint --raw
        ''}";
      };

      lint-desktop = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-desktop" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix build ${self}#checks.${system}.lint-desktop --no-link --print-build-logs
          echo "All desktop config checks passed."
        ''}";
      };

      lint-shell = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-shell" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix build ${self}#checks.${system}.lint-shell --no-link --print-build-logs
          echo "All shell config checks passed."
        ''}";
      };

      render-template = {
        type = "app";
        program = "${pkgs.writeShellScript "render-template" ''
          set -euo pipefail
          if [ "$#" -lt 2 ]; then
            echo "Usage: render-template <template-path> <theme>" >&2
            echo "Example: render-template terminal/ghostty/config/colors.conf monochrome" >&2
            exit 1
          fi
          ${pkgs.nix}/bin/nix eval ${self}#renderTemplateFor --apply "f: f \"$1\" \"$2\"" --raw
        ''}";
      };
    };
  };
}
