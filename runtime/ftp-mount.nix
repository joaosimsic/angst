{
  mkScript,
  pkgs,
}:
{
  repoPath,
  configFile,
  mountPoint,
}:
mkScript {
  name = "angst-ftp-mount";
  runtimeInputs = with pkgs; [
    rclone
    sops
    age
    coreutils
    jq
  ];
  text = ''
    set -euo pipefail

    work_key="''${SOPS_WORK_AGE_KEY_FILE:-$HOME/.config/sops/age/work-keys.txt}"
    conf="$HOME/${repoPath}/${configFile}"

    if [ ! -f "$conf" ]; then
      echo "warn: ftp config not found at $conf; nothing to mount" >&2
      exit 0
    fi
    if [ ! -f "$work_key" ]; then
      echo "warn: work age key not found at $work_key; cannot decrypt ftp config" >&2
      exit 0
    fi

    cmd="''${1:-}"
    case "$cmd" in
    mount) ;;
    unmount)
      fusermount3 -u "$HOME/${mountPoint}" 2>/dev/null || fusermount -u "$HOME/${mountPoint}" 2>/dev/null || true
      exit 0
      ;;
    *)
      echo "unknown ftp-mount command: $cmd" >&2
      exit 2
      ;;
    esac

    tmpdir="$XDG_RUNTIME_DIR/angst-ftp"
    mkdir -p "$tmpdir"
    chmod 700 "$tmpdir"
    tmpconf="$(mktemp "$tmpdir/ftp.XXXXXX.conf")"
    trap 'rm -f "$tmpconf"' EXIT

    SOPS_AGE_KEY_FILE="$work_key" sops -d --input-type binary --output-type binary "$conf" >"$tmpconf.json"

    remote="$(jq -r '.remote' "$tmpconf.json")"
    path="$(jq -r '.path // "/"' "$tmpconf.json")"

    {
      echo "[$remote]"
      jq -r '.config | to_entries[] | "\(.key) = \(.value|tostring)"' "$tmpconf.json"
    } >"$tmpconf"
    chmod 600 "$tmpconf"

    mkdir -p "$HOME/${mountPoint}"
    exec rclone mount --config "$tmpconf" --no-modtime --vfs-cache-mode off "$remote:$path" "$HOME/${mountPoint}"
  '';
}
