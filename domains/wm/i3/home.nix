{
  config,
  lib,
  pkgs,
  themeSys,
  store,
  host,
  ...
}:

let
  cfg = config.domains.wm.i3;

  i3Tools = pkgs.callPackage ./package.nix { };
  mouseHide = pkgs.callPackage ./mouse-hide.nix { inherit i3Tools; };
  vmGrab = pkgs.callPackage ./vm-grab.nix { };
  audioMute = pkgs.callPackage ./audio-mute.nix { };
  hardwareMetrics = pkgs.callPackage ../../bar/i3status-rust/hardware-metrics.nix { };
  hardwareMenu = pkgs.callPackage ./hardware-menu.nix { inherit hardwareMetrics; };
  networkMetrics = pkgs.callPackage ../../bar/i3status-rust/network-metrics.nix { };
  networkMenu = pkgs.callPackage ./network-menu.nix { inherit networkMetrics; };
  cheatsheet = pkgs.callPackage ./cheatsheet.nix { };
  lock = pkgs.callPackage ./lock.nix {
    theme = themeSys.get config.theme;
  };

  cap = config.domains.capture.screenshot or { enable = false; };
  notif = config.domains.notifications or { enable = false; };
  audio = config.domains.kernel.audio or { enable = false; };
  player = config.domains.media.celluloid or { enable = false; };
  inherit (store) hasX11 hasNotifications;
  shouldBind = cfg.enable && (cap.enable or false) && hasX11;
  shouldBindNotif = cfg.enable && (notif.enable or false) && hasX11 && hasNotifications;
  shouldBindAudio = cfg.enable && (audio.enable or false) && hasX11;
  shouldBindPlayer = cfg.enable && (player.enable or false) && hasX11;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      i3Tools
      mouseHide
      vmGrab
      lock
      hardwareMenu
      networkMenu
      cheatsheet
    ]
    ++ lib.optionals shouldBindAudio [ audioMute ];

    systemd.user = lib.mkIf (host.hostname != "vm") {
      paths.i3-vm-grab = {
        Unit.Description = "Watch for VM input grab requests";
        Path.PathChanged = "%S/vm/keys/vm/grab-request";
        Install.WantedBy = [ "default.target" ];
      };

      services.i3-vm-grab = {
        Unit.Description = "Toggle QEMU input grab for the VM";
        Service = {
          Type = "oneshot";
          Environment = [ "VM_GRAB_SHARED_DIR=%S/vm/keys/vm" ];
          ExecStart = "${vmGrab}/bin/i3-vm-grab handle-request";
        };
      };
    };

    xdg.configFile = {
      "i3/screenshot.conf".text = lib.mkDefault (
        if shouldBind then
          ''
            bindsym Print exec --no-startup-id angst-screenshot-save fullscreen
            bindsym Shift+Print exec --no-startup-id angst-screenshot-copy region
            bindsym $mod+Shift+s exec --no-startup-id angst-screenshot-copy region
            bindsym $mod+Print exec --no-startup-id angst-screenshot-save window
          ''
        else
          ""
      );

      "i3/notifications.conf".text = lib.mkDefault (
        if shouldBindNotif then
          ''
            bindsym $mod+Shift+n exec --no-startup-id angst-notify dismiss
            bindsym $mod+Shift+m exec --no-startup-id angst-notify dismiss-all
            bindsym $mod+Control+n exec --no-startup-id angst-notify history
          ''
        else
          ""
      );

      "i3/audio.conf".text = lib.mkDefault (
        if shouldBindAudio then
          ''
            bindsym XF86AudioRaiseVolume exec --no-startup-id wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
            bindsym XF86AudioLowerVolume exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
            bindsym XF86AudioMute exec --no-startup-id i3-audio-mute
            bindsym XF86AudioMicMute exec --no-startup-id wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
            bindsym $mod+plus exec --no-startup-id wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
            bindsym $mod+minus exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
            bindsym $mod+m exec --no-startup-id i3-audio-mute
          ''
        else
          ""
      );

      "i3/media.conf".text = lib.mkDefault (
        if shouldBindPlayer then
          ''
            bindsym XF86AudioPlay exec --no-startup-id playerctl play-pause
            bindsym XF86AudioPause exec --no-startup-id playerctl play-pause
            bindsym XF86AudioStop exec --no-startup-id playerctl stop
            bindsym XF86AudioNext exec --no-startup-id playerctl next
            bindsym XF86AudioPrev exec --no-startup-id playerctl previous
            bindsym $mod+Control+space exec --no-startup-id playerctl play-pause
          ''
        else
          ""
      );
    };

    assertions = [
      {
        assertion = !shouldBind || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 screenshot bindings require domains.kernel.graphical to be enabled";
      }
      {
        assertion = !shouldBindNotif || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 notification bindings require domains.kernel.graphical to be enabled";
      }
      {
        assertion = !shouldBindAudio || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 audio bindings require domains.kernel.graphical to be enabled";
      }
      {
        assertion = !shouldBindPlayer || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 media bindings require domains.kernel.graphical to be enabled";
      }
    ];
  };
}
