{
  mkScript,
  pkgs,
}:
{
  username,
  homeDirectory,
}:
mkScript {
  name = "angst-vm-age-key";
  runtimeInputs = with pkgs; [
    coreutils
  ];
  text = ''
    key_file=/tmp/shared/age-keys.txt

    if [ ! -s "$key_file" ]; then
      echo "No host age key found at $key_file; secrets will be unavailable."
      exit 0
    fi

    sops_dir="${homeDirectory}/.config/sops/age"
    install -d -m 700 -o ${username} -g users "$sops_dir"
    install -m 600 -o ${username} -g users "$key_file" "$sops_dir/keys.txt"
  '';
}
