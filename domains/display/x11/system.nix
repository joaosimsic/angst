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

  homeManagerProfile = "/etc/profiles/per-user/${userConfig.username}";
  homeManagerSessionVars = "${homeManagerProfile}/etc/profile.d/hm-session-vars.sh";
  displayApply = "${homeManagerProfile}/bin/angst-display";
in
{
  options.domains.display.x11 = {
    enable = lib.mkEnableOption "X11 session autostart";

    defaultMode = lib.mkOption {
      type = lib.types.enum [
        "dual"
        "stream"
      ];
      default = "dual";
      description = ''
        Default display mode when no persisted runtime state exists. "dual"
        enables all configured outputs; "stream" keeps only the primary output
        enabled. Runtime state is stored in ~/.local/state/angst/display/mode
        and can be changed with `angst-display stream|dual|toggle`.
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
          if [ -x ${lib.escapeShellArg displayApply} ]; then
            ${lib.escapeShellArg displayApply} apply ${lib.escapeShellArg cfg.defaultMode} || true
          fi

          ${pkgs.hsetroot}/bin/hsetroot -solid "#${p.background.base}"

          exec ${lib.getExe cfg.windowManager}
        '';
      }
    ];
  };
}
