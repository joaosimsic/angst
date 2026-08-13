{
  mkScript,
  pkgs,
}:
{
  username,
  homeDirectory,
  repoPath,
}:
mkScript {
  name = "angst-provision-ssh-key";
  runtimeInputs = with pkgs; [
    coreutils
    age
    openssh
  ];
  text = ''
    set -uo pipefail

    ssh_dir="${homeDirectory}/.ssh"
    repo="${homeDirectory}/${repoPath}"
    tmp_dir="$(mktemp -d)" || exit 1
    trap 'rm -rf "$tmp_dir"' EXIT
    umask 0077

    provision_scope() {
        local scope="$1" age_key="$2" dest="$3"
        local age_file="$repo/secrets/ssh/$scope.ed25519.age"
        local plain="$tmp_dir/$scope.key"
        local tmp_install="$ssh_dir/$dest.tmp"

        [ -f "$age_key" ] || return 0
        [ -f "$age_file" ] || return 0

        if ! age -d -i "$age_key" -o "$plain" "$age_file" 2>/dev/null; then
            echo "warn: could not decrypt $age_file; skipping $scope SSH key" >&2
            return 0
        fi
        chmod 600 "$plain"

        if ! ssh-keygen -y -f "$plain" >/dev/null 2>&1; then
            echo "warn: decrypted $scope key is invalid; leaving existing $dest untouched" >&2
            return 0
        fi

        if [ "$(id -u)" -eq 0 ]; then
            install -d -m 700 -o ${username} -g users "$ssh_dir"
            install -m 600 -o ${username} -g users "$plain" "$tmp_install"
        else
            install -d -m 700 "$ssh_dir"
            install -m 600 "$plain" "$tmp_install"
        fi
        mv -f "$tmp_install" "$ssh_dir/$dest"
        rm -f "$plain"
        echo "provisioned $scope SSH key -> $ssh_dir/$dest"
    }

    provision_scope personal "${homeDirectory}/.config/sops/age/keys.txt" "id_ed25519"
    provision_scope work "${homeDirectory}/.config/sops/age/work-keys.txt" "work_ed25519"
  '';
}
