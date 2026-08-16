{
  mkScript,
  pkgs,
  goAngst,
}:
{
  configFile,
  mountPoint,
}:
mkScript {
  name = "angst-ftp-mount";
  runtimeInputs = with pkgs; [
    rclone
    coreutils
  ];
  text = ''
    cmd="''${1:-}"
    case "$cmd" in
    mount)
      exec ${goAngst}/bin/angst ftp mount --conf "${configFile}" --mount-point "${mountPoint}"
      ;;
    unmount)
      exec ${goAngst}/bin/angst ftp unmount --mount-point "${mountPoint}"
      ;;
    *)
      echo "unknown ftp-mount command: $cmd" >&2
      exit 2
      ;;
    esac
  '';
}