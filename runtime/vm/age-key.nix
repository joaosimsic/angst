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
    work_key_file=/tmp/shared/work-keys.txt

    sops_dir="${homeDirectory}/.config/sops/age"
    install -d -m 700 -o ${username} -g users "$sops_dir"

    if [ -s "$key_file" ]; then
      install -m 600 -o ${username} -g users "$key_file" "$sops_dir/keys.txt"
    else
      echo "No host age key found at $key_file; personal secrets will be unavailable."
    fi

    if [ -s "$work_key_file" ]; then
      install -m 600 -o ${username} -g users "$work_key_file" "$sops_dir/work-keys.txt"
      echo "Installed work age key from shared dir."
    fi
  '';
}
