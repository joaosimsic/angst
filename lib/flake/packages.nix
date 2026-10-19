{
  context,
}:

let
  inherit (context)
    homeConfigurations
    representative
    representativeStore
    defaultSystem
    runtime
    hmSwitchTool
    pkgs
    lib
    themesLib
    ;
in
{
  packages.${defaultSystem} =
    let
      excludedNames = [
        "login-shell-valid"
        "login-shell-invalid"
        "${representative.username}-theme-override-test"
      ];
      hmPkgs = builtins.removeAttrs (builtins.mapAttrs (
        _: cfg: cfg.activationPackage
      ) homeConfigurations) excludedNames;
      extra =
        if representative != null then
          {
            default = homeConfigurations.${representative.username}.activationPackage;
            angst = runtime.angst-cli;
            vm-tool = runtime.vmTool;
            angst-shell = runtime.goShell;
            analyze = runtime.goAnalyze;
          }
        else
          { };

      paperRaw = pkgs.callPackage ../../domains/design/paper/package.nix { };
      paperBrowser =
        if representativeStore != null then representativeStore.defaultBrowser else "firefox";
      paperIsDark = if representative != null then (themesLib.get representative.theme).isDark else true;
      paperDesktop = pkgs.symlinkJoin {
        name = "paper-desktop-wrapped";
        paths = [ paperRaw ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/paper-desktop \
            --set BROWSER "${paperBrowser}" \
            ${lib.optionalString paperIsDark ''--add-flags "--force-dark-mode --enable-features=WebUIDarkMode,WebContentsForceDark --ozone-platform-hint=x11" --set ELECTRON_OZONE_PLATFORM_HINT x11 --set GTK_THEME Adwaita:dark''} \
            --run 'export XDG_DATA_DIRS="$HOME/.nix-profile/share:$HOME/.local/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"' \
            --run 'export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"'
        '';
      };
    in
    {
      hm-switch = hmSwitchTool;
      paper-desktop = paperDesktop;
    }
    // extra
    // hmPkgs;
}
