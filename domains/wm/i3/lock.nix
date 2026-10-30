{
  pkgs,
  theme,
}:

let
  p = theme.palette;
  a = theme.ansi;
in
pkgs.writeShellApplication {
  name = "i3-lock";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.xdotool
    pkgs.xsecurelock
    pkgs.xset
  ];
  text = ''
    export XSECURELOCK_PASSWORD_PROMPT=asterisks
    export XSECURELOCK_DISCARD_FIRST_KEYPRESS=1
    export XSECURELOCK_SINGLE_AUTH_WINDOW=1
    export XSECURELOCK_SHOW_USERNAME=0
    export XSECURELOCK_SHOW_HOSTNAME=0
    export XSECURELOCK_SHOW_DATETIME=0
    export XSECURELOCK_SHOW_KEYBOARD_LAYOUT=0
    export XSECURELOCK_BURNIN_MITIGATION=0
    export XSECURELOCK_BLANK_TIMEOUT=-1
    export XSECURELOCK_COMPOSITE_OBSCURER=0
    export XSECURELOCK_FONT="JetBrainsMono Nerd Font:size=16"
    export XSECURELOCK_BACKGROUND_COLOR="#${p.background.base}"
    export XSECURELOCK_AUTH_BACKGROUND_COLOR="#${p.background.base}"
    export XSECURELOCK_AUTH_FOREGROUND_COLOR="#${p.foreground.base}"
    export XSECURELOCK_AUTH_WARNING_COLOR="#${a.error}"

    xset s off || true
    xset dpms 0 0 300 || true
    trap 'xset dpms 0 0 0 || true' EXIT

    xsecurelock -- xdotool key Shift_L
  '';
}
