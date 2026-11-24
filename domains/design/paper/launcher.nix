{
  pkgs,
  lib,
  browser ? "firefox",
  isDark ? true,
}:

pkgs.writeShellApplication {
  name = "paper-desktop";
  runtimeInputs = with pkgs; [
    appimage-run
    coreutils
    curl
    gnugrep
    gnused
  ];
  text = ''
    url="https://download.paper.design/linux/appImage"
    data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
    app_dir="$data_home/paper-desktop"
    app="$app_dir/paper-desktop.AppImage"
    version_file="$app_dir/version"

    remote_version=""
    upstream_ok=false
    if headers="$(curl -fsSI --connect-timeout 5 "$url" 2>/dev/null)"; then
      upstream_ok=true
      remote_version="$(
        printf '%s\n' "$headers" \
          | tr -d '\r' \
          | sed -n 's/.*paper-desktop-\([0-9][0-9.]*\)x86_64\.AppImage.*/\1/p' \
          | head -n 1
      )"
    fi
    local_version="$(cat "$version_file" 2>/dev/null || true)"

    download() {
      mkdir -p "$app_dir"
      tmp="$app_dir/.paper-desktop.AppImage.part.$$"
      trap 'rm -f "$tmp"' EXIT

      if ! curl -fL --retry 3 --connect-timeout 10 -o "$tmp" "$url"; then
        echo "paper-desktop: download failed" >&2
        rm -f "$tmp"
        return 1
      fi

      chmod +x "$tmp"
      mv -f "$tmp" "$app"
      printf '%s\n' "''${remote_version:-unknown}" > "$version_file"
      trap - EXIT
    }

    if [ ! -x "$app" ]; then
      if [ "$upstream_ok" != true ]; then
        echo "paper-desktop: not installed and upstream is unreachable" >&2
        exit 1
      fi
      download
    elif [ -n "$remote_version" ] && [ "$remote_version" != "$local_version" ]; then
      download || echo "paper-desktop: update failed; using $local_version" >&2
    fi

    export BROWSER="${browser}"
    export XDG_DATA_HOME="$data_home"
    export XDG_DATA_DIRS="$HOME/.nix-profile/share:$data_home''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

    flags=()
    ${lib.optionalString isDark ''
      flags+=("--force-dark-mode" "--enable-features=WebUIDarkMode,WebContentsForceDark" "--ozone-platform-hint=x11")
      export ELECTRON_OZONE_PLATFORM_HINT=x11
      export GTK_THEME=Adwaita:dark
    ''}

    exec appimage-run "$app" "''${flags[@]}" "$@"
  '';
}
