{
  mkScript,
  pkgs,
}:
{
  username,
  sopsPath,
}:
mkScript {
  name = "angst-bootstrap-secrets";
  runtimeInputs = with pkgs; [
    coreutils
    mkpasswd
    shadow
  ];
  text = ''
    MASTER_PASSWORD=$(cat ${sopsPath})

    HASH=$(echo "$MASTER_PASSWORD" | mkpasswd -m sha-512 -s)
    usermod -p "$HASH" ${username}
    usermod -p "$HASH" root

    unset MASTER_PASSWORD
  '';
}
