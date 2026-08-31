{
  config,
  lib,
  pkgs,
  runtime,
  store,
  themesLib ? null,
  ...
}:

let
  cfg = config.domains.notifications;
  inherit (store) hasWayland hasX11;
  rawBackend = cfg.backend or "auto";
  effectiveBackend =
    if rawBackend == "auto" then
      if hasWayland && !hasX11 then "mako" else "dunst"
    else rawBackend;
  themeName = config.theme or "catppuccin-mocha";
  t =
    if themesLib != null then themesLib.get themeName
    else {
      palette = {
        background = { base = "#1e1e2e"; variant = "#1e1e2e"; };
        foreground = { base = "#cdd6f4"; variant = "#cdd6f4"; };
        accent = { base = "#89b4fa"; variant = "#89b4fa"; };
        surface = { base = "#89b4fa"; variant = "#a6e3a1"; };
        dim = "#f38ba8";
      };
      ansi = { error = "#f38ba8"; warn = "#f9e2af"; info = "#89dceb"; success = "#a6e3a1"; };
    };
  p = t.palette;
  angstNotify = runtime.notifications {
    backend = effectiveBackend;
    name = "angst-notify";
  };
in
{
  options.domains.notifications = {
    backend = lib.mkOption {
      type = lib.types.enum [ "auto" "dunst" "mako" ];
      default = "auto";
      description = "Notification backend. auto=detect hasWayland/hasX11, dunst=X11, mako=Wayland";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.domains.kernel.graphical.enable;
        message = "domains.notifications requires domains.kernel.graphical to be enabled";
      }
    ];
    home.packages = with pkgs; [ libnotify ] ++ [ angstNotify ];
    services = {
      dunst = {
        enable = effectiveBackend == "dunst";
        settings = lib.mkIf (effectiveBackend == "dunst") {
          global = {
            width = 350;
            height = 300;
            offset = "20x20";
            origin = "top-right";
            transparency = 0;
            frame_width = 2;
            frame_color = "#${p.accent.base}";
            separator_color = "#${p.accent.base}";
            font = "JetBrainsMono Nerd Font 10";
            background = "#${p.background.base}";
            foreground = "#${p.foreground.variant}";
            idle_threshold = 0;
            monitor = 0;
            follow = "mouse";
            sticky_history = "yes";
            history_length = 20;
            show_age_threshold = 60;
            ellipsize = "middle";
            ignore_newline = "no";
            stack_duplicates = true;
            hide_duplicate_count = false;
            sort = "yes";
            alignment = "left";
            vertical_alignment = "center";
            word_wrap = "yes";
            line_height = 0;
            notification_limit = 5;
            progress_bar = true;
            progress_bar_height = 10;
            progress_bar_frame_width = 1;
            progress_bar_min_width = 150;
            progress_bar_max_width = 300;
            indicate_hidden = "yes";
            shrink = "no";
            separator_height = 2;
            padding = 12;
            horizontal_padding = 12;
            text_icon_padding = 8;
            corner_radius = 6;
            mouse_left_click = "close_current";
            mouse_middle_click = "do_action, close_current";
            mouse_right_click = "close_all";
          };
          urgency_low = {
            background = "#${p.background.variant}";
            foreground = "#${p.foreground.variant}";
            frame_color = "#${p.accent.base}";
            timeout = 5;
          };
          urgency_normal = {
            background = "#${p.background.base}";
            foreground = "#${p.foreground.variant}";
            frame_color = "#${p.accent.base}";
            timeout = 8;
          };
          urgency_critical = {
            background = "#${p.background.base}";
            foreground = "#${t.ansi.error}";
            frame_color = "#${t.ansi.error}";
            timeout = 0;
          };
        };
      };
      mako = {
        enable = effectiveBackend == "mako";
        settings = lib.mkIf (effectiveBackend == "mako") {
          "background-color" = "#${p.background.base}";
          "text-color" = "#${p.foreground.variant}";
          "border-color" = "#${p.accent.base}";
          "border-size" = 2;
          "border-radius" = 6;
          font = "JetBrainsMono Nerd Font 10";
          width = 350;
          height = 300;
          margin = "20";
          padding = "12";
          "default-timeout" = 8000;
          history = 1;
          "max-visible" = 5;
          sort = "-time";
          layer = "overlay";
          anchor = "top-right";
          icons = 1;
          "max-icon-size" = 48;
          "progress-color" = "over #${p.accent.base}";
          "urgency=high" = {
            "background-color" = "#${p.background.base}";
            "text-color" = "#${t.ansi.error}";
            "border-color" = "#${t.ansi.error}";
            "default-timeout" = 0;
          };
        };
      };
    };
  };
}
