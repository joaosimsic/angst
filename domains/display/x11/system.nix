{
  config,
  lib,
  pkgs,
  theme,
  themesLib,
  monitors,
  userConfig,
  ...
}:

let
  cfg = config.domains.display.x11;
  t = themesLib.get theme;
  p = t.palette;
  gtkTheme = if t.isDark then "Adwaita:dark" else "Adwaita";

  monitorCommand =
    m: primary:
    let
      primaryFlag = lib.optionalString primary " --primary";
      pos = m.position or "0x0";
      rate = toString (m.refreshRate or 60);
      resolution = m.resolution or "auto";
    in
    if resolution == "auto" then
      ''
        ${pkgs.xrandr}/bin/xrandr --output ${m.name} \
          --auto \
          --pos ${pos}${primaryFlag}
      ''
    else if resolution == "kernel" then
      ''
        res=""
        for arg in $(${pkgs.coreutils}/bin/cat /proc/cmdline); do
          case "$arg" in
            video=${m.name}:*)
              res="''${arg#video=${m.name}:}"
              res="''${res%@*}"
              ;;
          esac
        done
        if [ -n "$res" ]; then
          ${pkgs.xrandr}/bin/xrandr --output ${m.name} \
            --mode "$res" \
            --rate ${rate} \
            --pos ${pos}${primaryFlag}
        fi
      ''
    else
      ''
        ${pkgs.xrandr}/bin/xrandr --output ${m.name} \
          --mode ${resolution} \
          --rate ${rate} \
          --pos ${pos}${primaryFlag}
      '';

  primaryLine =
    if monitors ? primary && monitors.primary ? name then monitorCommand monitors.primary true else "";

  nonPrimary = lib.filterAttrs (name: m: name != "primary" && m ? name) monitors;

  secondaryLines =
    if cfg.headlessPrimaryOnly then
      lib.concatStrings (
        lib.mapAttrsToList (_: m: ''
          ${pkgs.xrandr}/bin/xrandr --output ${m.name} --off 2>/dev/null || true
        '') nonPrimary
      )
    else
      lib.concatStrings (lib.mapAttrsToList (_: m: monitorCommand m false) nonPrimary);

  homeManagerSessionVars = "/etc/profiles/per-user/${userConfig.username}/etc/profile.d/hm-session-vars.sh";
in
{
  options.domains.display.x11 = {
    enable = lib.mkEnableOption "X11 session autostart";

    headlessPrimaryOnly = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Configure only the primary output in the X session and power off the
        remaining configured outputs. Useful for headless streaming; enable a
        secondary output again with `angst-display`.
      '';
    };

    windowManager = lib.mkOption {
      type = lib.types.package;
      default = pkgs.i3;
      description = "Window manager launched by the angst X11 session";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.domains.kernel.graphical.enable;
        message = "domains.display.x11 requires domains.kernel.graphical to be enabled";
      }
    ];

    services.xserver.displayManager.session = [
      {
        manage = "desktop";
        name = "i3";
        start = ''
          #!${pkgs.bash}/bin/sh

          export GTK_THEME="${gtkTheme}"
          export SAL_USE_VCLPLUGIN=gtk3
          export QT_QPA_PLATFORMTHEME=kde
          export QT_STYLE_OVERRIDE=breeze

          if [ -f ${lib.escapeShellArg homeManagerSessionVars} ]; then
            . ${lib.escapeShellArg homeManagerSessionVars}
          elif [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
            . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
          fi

          ${primaryLine}
          ${secondaryLines}

          ${pkgs.hsetroot}/bin/hsetroot -solid "#${p.background.base}"

          exec ${lib.getExe cfg.windowManager}
        '';
      }
    ];
  };
}
