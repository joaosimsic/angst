{
  mkScript,
  pkgs,
}:
{
  username,
  homeDirectory,
}:
mkScript {
  name = "angst-vm-authorized-keys";
  runtimeInputs = with pkgs; [
    coreutils
  ];
  text = ''
    key_file=/tmp/shared/authorized_keys

    if [ ! -s "$key_file" ]; then
      echo "No runtime VM SSH keys found at $key_file; keeping declarative authorized_keys fallback."
      exit 0
    fi

    install -d -m 700 -o ${username} -g users ${homeDirectory}/.ssh
    install -m 600 -o ${username} -g users "$key_file" ${homeDirectory}/.ssh/authorized_keys
  '';
}
