{
  pkgs,
}:

pkgs.writeShellApplication {
  name = "i3-cheatsheet";
  runtimeInputs = [
    pkgs.conky
    pkgs.coreutils
    pkgs.gawk
    pkgs.i3
    pkgs.xdotool
  ];
  text = ''
    set -euo pipefail

    runtime="''${XDG_RUNTIME_DIR:-/tmp}"
    config="''${I3_CONFIG:-$HOME/.config/i3/config}"
    cache="$HOME/.cache/i3-cheatsheet.txt"
    pid_file="$runtime/i3-cheatsheet.pid"
    log_file="$runtime/i3-cheatsheet.log"
    quote='"'

    declare -a files=()
    declare -A seen=()

    collect() {
      local file="$1" line inc expanded
      [[ -r "$file" ]] || return 0
      file="$(realpath -m -- "$file")"
      [[ -n "''${seen[$file]:-}" ]] && return 0
      seen[$file]=1
      files+=("$file")

      while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*include[[:space:]]+(.+)$ ]]; then
          inc="''${BASH_REMATCH[1]}"
          inc="''${inc%"$quote"}"
          inc="''${inc#"$quote"}"
          inc="''${inc/#\~/$HOME}"
          # shellcheck disable=SC2086
          for expanded in $inc; do
            collect "$expanded"
          done
        fi
      done < "$file"
    }

    generate() {
      local source="$1"
      files=()
      seen=()
      collect "$source"
      if [[ ''${#files[@]} -eq 0 ]]; then
        echo "i3-cheatsheet: config not found: $source" >&2
        return 1
      fi
      awk -f ${./cheatsheet.awk} "''${files[@]}"
    }

    toggle() {
      if [[ -s "$pid_file" ]]; then
        local running
        running="$(cat "$pid_file" 2>/dev/null || true)"
        if [[ -n "$running" ]] && kill -0 "$running" 2>/dev/null; then
          kill "$running" 2>/dev/null || true
          rm -f "$pid_file"
          return 0
        fi
        rm -f "$pid_file"
      fi

      mkdir -p "$HOME/.cache"
      generate "$HOME/.config/i3/config" > "$cache.tmp"
      mv "$cache.tmp" "$cache"

      conky -c "$HOME/.config/i3/cheatsheet.conky" >/dev/null 2>"$log_file" &
      local pid=$!
      printf '%s\n' "$pid" > "$pid_file"
      if timeout 2 xdotool search --sync --onlyvisible --class '^i3-cheatsheet$' >/dev/null 2>&1; then
        sleep 0.1
        i3-msg -q '[class="^i3-cheatsheet$"] move to workspace current, move position center' >/dev/null 2>&1 || true
      fi
      wait "$pid" || true
      rm -f "$pid_file"
    }

    case "''${1:-toggle}" in
      toggle) toggle ;;
      generate) generate "''${2:-$config}" ;;
      *)
        echo "usage: i3-cheatsheet [toggle|generate] [config]" >&2
        exit 2
        ;;
    esac
  '';
}
