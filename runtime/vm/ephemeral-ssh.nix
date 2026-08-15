{
  mkScript,
  pkgs,
}:
mkScript {
  name = "angst-vm-ephemeral-ssh";
  runtimeInputs = with pkgs; [
    coreutils
    util-linux
  ];
  text = ''
    if ! ${pkgs.util-linux}/bin/mountpoint -q /etc/ssh; then
      ${pkgs.util-linux}/bin/mount -t tmpfs tmpfs /etc/ssh -o mode=0755
    fi
    # On a switch, /etc/ssh is already a tmpfs that switch-to-configuration
    # re-populated (as symlinks into the new closure). rm before cp so a dst
    # that is the same file as the source (or a symlink into the read-only
    # store) is replaced instead of failing with "same file".
    for f in /run/current-system/etc/ssh/sshd_config /etc/static/ssh/sshd_config; do
      if [ -f "$f" ]; then
        ${pkgs.coreutils}/bin/rm -f /etc/ssh/sshd_config
        ${pkgs.coreutils}/bin/cp "$f" /etc/ssh/sshd_config
        break
      fi
    done
    # The tmpfs mount above hides the system's authorized_keys.d. Copy the
    # baked-in keys back so sshd (AuthorizedKeysFile /etc/ssh/...) can read them.
    for d in /run/current-system/etc/ssh/authorized_keys.d /etc/static/ssh/authorized_keys.d; do
      if [ -d "$d" ]; then
        ${pkgs.coreutils}/bin/mkdir -p /etc/ssh/authorized_keys.d
        for f in "$d"/*; do
          case "$(${pkgs.coreutils}/bin/basename "$f")" in
            *.uid|*.gid|*.mode) continue ;;
          esac
          if [ -f "$f" ]; then
            dst="/etc/ssh/authorized_keys.d/$(${pkgs.coreutils}/bin/basename "$f")"
            ${pkgs.coreutils}/bin/rm -f "$dst"
            ${pkgs.coreutils}/bin/cp "$f" "$dst"
          fi
        done
        break
      fi
    done
  '';
}
