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
    mount -t tmpfs tmpfs /etc/ssh -o mode=0755
    for f in /run/current-system/etc/ssh/sshd_config /etc/static/ssh/sshd_config; do
      if [ -f "$f" ]; then
        cp "$f" /etc/ssh/sshd_config
        break
      fi
    done
    # The tmpfs mount above hides the system's authorized_keys.d. Copy the
    # baked-in keys back so sshd (AuthorizedKeysFile /etc/ssh/...) can read them.
    for d in /run/current-system/etc/ssh/authorized_keys.d /etc/static/ssh/authorized_keys.d; do
      if [ -d "$d" ]; then
        mkdir -p /etc/ssh/authorized_keys.d
        for f in "$d"/*; do
          case "$(basename "$f")" in
            *.uid|*.gid|*.mode) continue ;;
          esac
          [ -f "$f" ] && cp "$f" /etc/ssh/authorized_keys.d/
        done
        break
      fi
    done
  '';
}
