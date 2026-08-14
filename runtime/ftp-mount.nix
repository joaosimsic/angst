{
  mkScript,
  pkgs,
}:
{
  configFile,
  mountPoint,
}:
mkScript {
  name = "angst-ftp-mount";
  runtimeInputs = with pkgs; [
    rclone
    jq
    coreutils
  ];
  text = ''
    set -euo pipefail

    conf="$HOME/${configFile}"

    if [ ! -f "$conf" ]; then
      echo "warn: ftp config not found at $conf; nothing to mount" >&2
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

    remote="$(jq -r '.remote' "$conf")"
    path="$(jq -r '.path // "/"' "$conf")"

    {
      echo "[$remote]"
      jq -r '.config | to_entries[] | "\(.key) = \(.value|tostring)"' "$conf"
    } >"$tmpconf"
    chmod 600 "$tmpconf"

    mkdir -p "$HOME/${mountPoint}"
    exec rclone mount --config "$tmpconf" --no-modtime --vfs-cache-mode off "$remote:$path" "$HOME/${mountPoint}"
  '';
}
