{
  mkScript,
  pkgs,
}:
{
  username,
  homeDirectory,
  injectWorkKey ? false,
}:
mkScript {
  name = "angst-vm-age-key";
  runtimeInputs = with pkgs; [
    coreutils
  ];
  excludeShellChecks = [ "SC2050" ];
  text =
    let
      injectStr = if injectWorkKey then "true" else "false";
    in
    ''
      key_file=/tmp/shared/age-keys.txt

      if [ ! -s "$key_file" ]; then
        echo "No host age key found at $key_file; secrets will be unavailable."
        exit 0
      fi

      sops_dir="${homeDirectory}/.config/sops/age"
      install -d -m 700 -o ${username} -g users "$sops_dir"
      install -m 600 -o ${username} -g users "$key_file" "$sops_dir/keys.txt"

      if [ "${injectStr}" = "true" ]; then
        work_key=/tmp/shared/work-keys.txt
        if [ -s "$work_key" ]; then
          install -m 600 -o ${username} -g users "$work_key" "$sops_dir/work-keys.txt"
        else
          echo "warn: work age key requested but not found at $work_key" >&2
        fi
      fi
    '';
}
