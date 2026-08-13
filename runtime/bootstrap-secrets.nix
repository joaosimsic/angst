{
  mkScript,
  pkgs,
}:
{
  username,
  hostname,
  sopsPath,
}:
mkScript {
  name = "angst-bootstrap-secrets";
  runtimeInputs = with pkgs; [
    coreutils
    mkpasswd
    shadow
    openssh
  ];
  text = ''
    MASTER_PASSWORD=$(cat ${sopsPath})

    HASH=$(echo "$MASTER_PASSWORD" | mkpasswd -m sha-512 -s)
    usermod -p "$HASH" ${username}
    usermod -p "$HASH" root

    KEY_FILE="/home/${username}/.ssh/id_ed25519"
    SSH_DIR="$(dirname "$KEY_FILE")"

    if [ ! -f "$KEY_FILE" ]; then
      mkdir -p "$SSH_DIR"
      ssh-keygen -t ed25519 -f "$KEY_FILE" -N "$MASTER_PASSWORD" -C "${username}@${hostname}"
      chown -R ${username}: "$SSH_DIR"
    else
      if ! ssh-keygen -y -P "$MASTER_PASSWORD" -f "$KEY_FILE" > /dev/null 2>&1; then
        ssh-keygen -p -N "$MASTER_PASSWORD" -f "$KEY_FILE" 2>/dev/null || \
          ssh-keygen -p -P "" -N "$MASTER_PASSWORD" -f "$KEY_FILE" 2>/dev/null
      fi
    fi

    unset MASTER_PASSWORD
  '';
}
