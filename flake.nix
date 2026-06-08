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
        tokens = themesLib.get themeName;
      };

    themeLint = import ./lib/lintThemes.nix {
      inherit lib themesLib domainsPath;
    };
  in
  {
    inherit themeLint renderTemplateFor;

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

      theme-override =
        let
          theme = self.homeConfigurations.joao-theme-override-test.config.theme;
        in
        if theme != "catppuccin-mocha" then
          throw "expected config.theme = catppuccin-mocha, got ${theme}"
        else
          pkgs.writeText "theme-override-check" "ok";

      home-catppuccin-mocha =
        self.homeConfigurations.joao-theme-override-test.activationPackage;
    };

    apps.${system} = {
      lint-themes = {
        type = "app";
        program = "${pkgs.writeShellScript "lint-themes" ''
          set -euo pipefail
          ${pkgs.nix}/bin/nix eval ${self}#themeLint --raw
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
