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

  isSunshineHost = host.remoteStream.role == "host" || host.remoteStream.role == "both";

  serviceTheme = ''
    [block.theme_overrides]
    idle_bg = "#${p.background.variant}"
    idle_fg = "#${p.foreground.base}"
    good_bg = "#${p.background.variant}"
    good_fg = "#${t.ansi.success}"
    warning_bg = "#${p.background.variant}"
    warning_fg = "#${t.ansi.warn}"
    critical_bg = "#${p.background.variant}"
    critical_fg = "#${t.ansi.error}"
  '';

  sunshineStatusBlock = lib.optionalString isSunshineHost ''
    [[block]]
    block = "custom"
    interval = 2
    json = true
    shell = "/bin/sh"
    command = "i3-sunshine-status"
    hide_when_empty = true
    merge_with_next = true
    format = " $icon "
    ${serviceTheme}
    [[block.click]]
    button = "left"
    cmd = "i3-toggles toggle sunshine"
    update = true
    [[block.click]]
    button = "right"
    cmd = "xdg-open https://localhost:47990"
  '';

  ftpStatusBlock = lib.optionalString ((host.ftp.mounts or [ ]) != [ ]) ''
    [[block]]
    block = "custom"
    interval = 5
    json = true
    shell = "/bin/sh"
    if_command = "command -v angst-ftp-status >/dev/null 2>&1"
    command = "angst-ftp-status"
    hide_when_empty = true
    merge_with_next = true
    format = " $icon $text "
    ${serviceTheme}
    [[block.click]]
    button = "left"
    cmd = "angst-ftp-status toggle"
    update = true
  '';
in
[
  {
    path = "domains/bar/i3status-rust/config/config.toml";
    text = ''
      [icons]
      icons = "material-nf"

      [icons.overrides]
      net_wifi = "\U000F05A9"
      net_offline = "\U000F05AA"
      sunshine = "\U000F0118"
      sunshine_active = "\U000F0119"

      [theme]
      theme = "plain"
      [theme.overrides]
      idle_bg = "#${p.background.base}"
      idle_fg = "#${p.foreground.base}"
      separator_bg = "#${p.background.base}"
      separator_fg = "#${p.accent.base}"

      [[block]]
      block = "custom"
      interval = 2
      json = true
      shell = "/bin/sh"
      command = "i3-vpn-status"
      hide_when_empty = true
      merge_with_next = true
      format = " $icon "
      ${serviceTheme}
      [[block.click]]
      button = "left"
      cmd = "i3-toggles toggle work-vpn"
      update = true

      ${sunshineStatusBlock}
      ${ftpStatusBlock}

      [[block]]
      block = "custom"
      interval = 1
      json = true
      shell = "/bin/sh"
      if_command = "command -v angst-discord-voice >/dev/null 2>&1"
      command = "angst-discord-voice status"
      hide_when_empty = true
      merge_with_next = true
      format = " $icon $text "
      ${serviceTheme}
      [[block.click]]
      button = "left"
      cmd = "i3-msg -q '[class=\"Discord\"] focus' 2>/dev/null || discord"

      [[block]]
      block = "custom"
      interval = 1
      json = true
      shell = "/bin/sh"
      command = "${grabStatus}"
      hide_when_empty = true
      merge_with_next = true
      format = " $icon $text "
      ${serviceTheme}
      [[block.click]]
      button = "left"
      cmd = "${grabClick}"
      update = true

      [[block]]
      block = "custom"
      interval = 1
      json = true
      shell = "/bin/sh"
      if_command = "command -v i3-mouse-hide >/dev/null 2>&1"
      command = "i3-mouse-hide status"
      hide_when_empty = true
      merge_with_next = true
      format = " $icon "
      ${serviceTheme}
      [[block.click]]
      button = "left"
      cmd = "i3-mouse-hide toggle"
      update = true

      [[block]]
      block = "custom"
      interval = 1
      json = true
      shell = "/bin/sh"
      command = "i3-services-separator"
      hide_when_empty = true
      merge_with_next = true
      format = "$text"
      [block.theme_overrides]
      idle_bg = "#${p.background.variant}"
      idle_fg = "#${p.accent.base}"

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

      [[block]]
      block = "custom"
      interval = 2
      json = true
      command = "i3-network-metrics"
      format = " $icon "
      [block.theme_overrides]
      warning_fg = "#${p.background.base}"
      warning_bg = "#${t.ansi.warn}"
      critical_fg = "#${p.background.base}"
      critical_bg = "#${t.ansi.error}"
      [[block.click]]
      button = "left"
      cmd = "sh -c 'command -v i3-network-menu >/dev/null 2>&1 && i3-network-menu'"

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
      block = "time"
      interval = 5
      format = " <span color='#${p.foreground.variant}'>$timestamp.datetime(f:'%Y-%m-%d %H:%M')</span> "
    '';
  }
]
