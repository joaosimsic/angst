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
  '';
}
