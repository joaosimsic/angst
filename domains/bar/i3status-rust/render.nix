{
  lib,
  themesLib,
  themeName,
  host,
}:

let
  t = themesLib.get themeName;
  p = t.palette;
  isVm = host.hostname == "vm";
  grabStatus = if isVm then "i3-vm-grab status --guest" else "i3-vm-grab status";
  grabClick = if isVm then "i3-vm-grab request" else "i3-vm-grab toggle";

  ftpStatusBlock = lib.optionalString ((host.ftp.mounts or [ ]) != [ ]) ''
    [[block]]
    block = "custom"
    interval = 5
    json = true
    shell = "/bin/sh"
    if_command = "command -v angst-ftp-status >/dev/null 2>&1"
    command = "angst-ftp-status"
    hide_when_empty = true
    format = " $icon $text "
    [block.theme_overrides]
    good_fg = "#${t.ansi.success}"
    good_bg = "#${p.background.base}"
    warning_fg = "#${p.background.base}"
    warning_bg = "#${t.ansi.warn}"
  '';
in
[
  {
    path = "domains/bar/i3status-rust/config/config.toml";
    text = ''
      [icons]
      icons = "material-nf"

      [theme]
      theme = "plain"
      [theme.overrides]
      idle_bg = "#${p.background.base}"
      idle_fg = "#${p.foreground.base}"
      separator_bg = "#${p.background.base}"
      separator_fg = "#${p.accent.base}"

      [[block]]
      block = "custom"
      interval = 5
      json = true
      command = "i3-hardware-metrics"
      format = " $text "
      [block.theme_overrides]
      warning_fg = "#${p.background.base}"
      warning_bg = "#${t.ansi.warn}"
      critical_fg = "#${p.background.base}"
      critical_bg = "#${t.ansi.error}"
      [[block.click]]
      button = "left"
      cmd = "sh -c 'command -v i3-hardware-menu >/dev/null 2>&1 && i3-hardware-menu'"

      ${ftpStatusBlock}
      [[block]]
      block = "sound"
      driver = "pulseaudio"
      step_width = 5
      max_vol = 150
      show_volume_when_muted = true
      format = " $icon {$volume.eng(w:2)|} "
      [block.theme_overrides]
      warning_fg = "#${t.ansi.error}"
      warning_bg = "#${p.background.base}"
      [[block.click]]
      button = "left"
      cmd = "pavucontrol"

      [[block]]
      block = "custom"
      interval = 1
      json = true
      shell = "/bin/sh"
      if_command = "command -v angst-discord-voice >/dev/null 2>&1"
      command = "angst-discord-voice status"
      hide_when_empty = true
      format = " $icon $text "
      [block.theme_overrides]
      good_fg = "#${t.ansi.success}"
      good_bg = "#${p.background.base}"
      warning_fg = "#${t.ansi.warn}"
      warning_bg = "#${p.background.base}"
      critical_fg = "#${t.ansi.error}"
      critical_bg = "#${p.background.base}"
      [[block.click]]
      button = "left"
      cmd = "i3-msg -q '[class=\"Discord\"] focus' 2>/dev/null || discord"

      [[block]]
      block = "custom"
      interval = 1
      json = true
      shell = "/bin/sh"
      if_command = "command -v i3-mouse-hide >/dev/null 2>&1"
      command = "i3-mouse-hide status"
      format = " $icon "
      [block.theme_overrides]
      good_fg = "#${t.ansi.success}"
      good_bg = "#${p.background.base}"
      critical_fg = "#${t.ansi.error}"
      critical_bg = "#${p.background.base}"
      [[block.click]]
      button = "left"
      cmd = "i3-mouse-hide toggle"
      update = true

      [[block]]
      block = "custom"
      interval = 1
      json = true
      shell = "/bin/sh"
      command = "${grabStatus}"
      hide_when_empty = true
      format = " $icon $text "
      [block.theme_overrides]
      good_fg = "#${t.ansi.success}"
      good_bg = "#${p.background.base}"
      critical_fg = "#${t.ansi.error}"
      critical_bg = "#${p.background.base}"
      [[block.click]]
      button = "left"
      cmd = "${grabClick}"
      update = true

      [[block]]
      block = "time"
      interval = 5
      format = " <span color='#${p.foreground.variant}'>$timestamp.datetime(f:'%Y-%m-%d %H:%M')</span> "
    '';
  }
]
