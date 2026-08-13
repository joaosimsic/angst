{
  mkScript,
  pkgs,
}:
{ username }:
mkScript {
  name = "angst-vm-home-manager-upgrade";
  runtimeInputs = with pkgs; [
    coreutils
    gnused
    systemd
  ];
  text = ''
    active_hp=""
    service_exec="$(systemctl show home-manager-${username} -p ExecStart 2>/dev/null || true)"
    active_gen="$(echo "$service_exec" | sed -n 's/.* \([^ ]*\)-home-manager-generation.*/\1-home-manager-generation/p')"
    if [ -n "$active_gen" ] && [ -L "$active_gen/home-path" ]; then
      active_hp="$(readlink -f "$active_gen/home-path" 2>/dev/null || true)"
    fi

    if [ -z "$active_hp" ]; then
      echo "Could not determine active home-manager-path; nothing to upgrade."
      exit 0
    fi

    latest=""
    shopt -s nullglob 2>/dev/null || true
    for gen in /nix/store/*-home-manager-generation/activate; do
      [ -f "$gen" ] || continue
      dir="''${gen%/activate}" || continue
      hp="$(readlink -f "$dir/home-path" 2>/dev/null || true)"
      [ -n "$hp" ] || continue
      [ "$hp" = "$active_hp" ] && continue
      latest="$dir"
    done

    if [ -n "$latest" ] && [ -x "$latest/activate" ]; then
      "$latest/activate" --driver-version 1 || true
    fi
  '';
}
