{
  config,
  pkgs,
  opencodePackage,
  portStart,
  portEnd,
  idleTimeout,
}:

let
  opencode = "${opencodePackage}/bin/opencode";
  secretFile = "${config.home.homeDirectory}/.secrets/opencode-go-key";
  stateRoot = "${config.xdg.stateHome}/opencode/mux";
  passwordFile = "${stateRoot}/password";
in
pkgs.writeShellApplication {
  name = "opencode-mux";
  runtimeInputs = with pkgs; [
    coreutils
    curl
    gnugrep
    iproute2
    jq
    openssl
    systemd
    util-linux
  ];
  text = ''
    state_root="${stateRoot}"
    password_file="${passwordFile}"
    secret_file="${secretFile}"
    port_start=${toString portStart}
    port_end=${toString portEnd}
    idle_timeout=${toString idleTimeout}

    runtime_root="''${XDG_RUNTIME_DIR:-/tmp/opencode-mux-$(id -u)}/opencode-mux"
    lock_file="$runtime_root/lock"

    ensure_dirs() {
      mkdir -p "$state_root" "$runtime_root"
      chmod 700 "$state_root" "$runtime_root"
    }

    ensure_password() {
      ensure_dirs
      if [ ! -s "$password_file" ]; then
        (
          flock 9
          if [ ! -s "$password_file" ]; then
            (
              umask 077
              openssl rand -hex 32 > "$password_file"
            )
          fi
        ) 9>"$state_root/password.lock"
      fi
    }

    read_password() {
      ensure_password
      cat "$password_file"
    }

    health() {
      local port=$1
      local password
      password="$(read_password)"
      printf 'user = "opencode:%s"\nsilent\nshow-error\nfail\nmax-time = 2\n' "$password" |
        curl --config - "http://127.0.0.1:$port/global/health"
    }

    health_ok() {
      health "$1" >/dev/null 2>&1
    }

    project_hash() {
      printf '%s' "$1" | sha256sum | cut -c1-16
    }

    unit_for() {
      printf 'opencode-mux@%s.service' "$1"
    }

    port_free() {
      ! ss -4 -H -ltn "sport = :$1" 2>/dev/null | grep -q .
    }

    choose_port() {
      local port
      for port in $(seq "$port_start" "$port_end"); do
        if port_free "$port"; then
          printf '%s\n' "$port"
          return 0
        fi
      done
      return 1
    }

    write_state() {
      local state=$1 dir=$2 port=$3 hash=$4
      printf 'OPENCODE_MUX_DIR=%s\nOPENCODE_MUX_PORT=%s\n' "$dir" "$port" > "$state/server.env"
      printf '%s\n' "$dir" > "$state/dir"
      printf '%s\n' "$port" > "$state/port"
      printf '%s\n' "$(unit_for "$hash")" > "$state/unit"
    }

    ensure_server() {
      local dir hash state unit port old_port health_json client_version server_version
      dir="$(realpath "$1")"
      hash="$(project_hash "$dir")"
      state="$runtime_root/$hash"
      unit="$(unit_for "$hash")"
      mkdir -p "$state/clients"

      exec 9>"$lock_file"
      flock 9
      ensure_password

      old_port=""
      if [ -f "$state/port" ]; then
        old_port="$(cat "$state/port")"
      fi

      if [ -n "$old_port" ] && health_ok "$old_port"; then
        health_json="$(health "$old_port" 2>/dev/null || true)"
        server_version="$(printf '%s' "$health_json" | jq -r '.version // empty' 2>/dev/null || true)"
        client_version="$("${opencode}" --version 2>/dev/null || true)"
        if [ -z "$server_version" ] || [ -z "$client_version" ] || [ "$server_version" = "$client_version" ]; then
          flock -u 9
          exec 9>&-
          printf '%s\n' "$old_port"
          return 0
        fi
        systemctl --user stop "$unit" >/dev/null 2>&1 || true
      fi

      systemctl --user stop "$unit" >/dev/null 2>&1 || true

      if [ -n "$old_port" ] && port_free "$old_port"; then
        port="$old_port"
      else
        if ! port="$(choose_port)"; then
          echo "opencode-mux: no free port in ${toString portStart}-${toString portEnd}" >&2
          flock -u 9
          exec 9>&-
          return 1
        fi
      fi

      if ! systemctl --user cat "$unit" >/dev/null 2>&1; then
        echo "opencode-mux: systemd unit $unit is not installed" >&2
        flock -u 9
        exec 9>&-
        return 1
      fi

      write_state "$state" "$dir" "$port" "$hash"
      systemctl --user start "$unit" >/dev/null 2>&1 || true

      for _ in $(seq 1 120); do
        if health_ok "$port"; then
          flock -u 9
          exec 9>&-
          printf '%s\n' "$port"
          return 0
        fi
        sleep 0.5
      done

      echo "opencode-mux: server failed to start for $dir" >&2
      journalctl --user -u "$unit" -n 40 --no-pager >&2 2>/dev/null || true
      flock -u 9
      exec 9>&-
      return 1
    }

    count_clients() {
      local state=$1 marker pid count=0
      mkdir -p "$state/clients"
      for marker in "$state/clients"/*; do
        [ -e "$marker" ] || continue
        pid="''${marker##*/}"
        if [ -d "/proc/$pid" ]; then
          count=$((count + 1))
        else
          rm -f "$marker"
        fi
      done
      printf '%s\n' "$count"
    }

    cmd_server() {
      if [ -z "''${OPENCODE_MUX_DIR:-}" ] || [ -z "''${OPENCODE_MUX_PORT:-}" ]; then
        echo "opencode-mux server: OPENCODE_MUX_DIR and OPENCODE_MUX_PORT are required" >&2
        exit 1
      fi
      case "$OPENCODE_MUX_PORT" in
        ""|*[!0-9]*)
          echo "opencode-mux server: invalid port: $OPENCODE_MUX_PORT" >&2
          exit 1
          ;;
      esac
      if [ ! -d "$OPENCODE_MUX_DIR" ]; then
        echo "opencode-mux server: missing project directory: $OPENCODE_MUX_DIR" >&2
        exit 1
      fi

      ensure_password
      if [ -r "$secret_file" ]; then
        local api_key
        api_key="$(< "$secret_file")"
        export OPENCODE_GO_API_KEY="$api_key"
      else
        echo "opencode-mux: warning: $secret_file is missing or unreadable" >&2
      fi
      local password
      password="$(read_password)"
      export OPENCODE_SERVER_PASSWORD="$password"
      export OPENCODE_DISABLE_AUTOUPDATE=true

      cd "$OPENCODE_MUX_DIR"
      exec "${opencode}" serve --hostname 127.0.0.1 --port "$OPENCODE_MUX_PORT"
    }

    cmd_client() {
      local original=("$@")
      local dir="$PWD"
      local -a args=()
      local hash state marker port unit

      if [ "$#" -gt 0 ] && [ "''${1#-}" = "$1" ] && [ -d "$1" ]; then
        dir="$(realpath "$1")"
        shift
      fi
      args=("$@")

      hash="$(project_hash "$dir")"
      state="$runtime_root/$hash"
      mkdir -p "$state/clients"
      marker="$state/clients/$$"
      : > "$marker"
      rm -f "$state/empty_since"

      cleanup_marker() {
        rm -f "$marker"
      }
      trap cleanup_marker EXIT

      if ! port="$(ensure_server "$dir")"; then
        cleanup_marker
        trap - EXIT
        if [ "''${OPENCODE_MUX_FALLBACK:-0}" = "1" ]; then
          echo "opencode-mux: falling back to standalone OpenCode" >&2
          exec "${opencode}" "''${original[@]}"
        fi
        exit 1
      fi

      ensure_password
      local password
      password="$(read_password)"
      export OPENCODE_SERVER_PASSWORD="$password"

      "${opencode}" attach "http://127.0.0.1:$port" --dir "$dir" "''${args[@]}"
    }

    cmd_reap() {
      local state unit marker pid count now empty_since
      [ -d "$runtime_root" ] || return 0

      for state in "$runtime_root"/*; do
        [ -d "$state" ] || continue
        [ -f "$state/unit" ] || continue
        unit="$(cat "$state/unit")"

        count="$(count_clients "$state")"
        if [ "$count" -gt 0 ]; then
          rm -f "$state/empty_since"
          continue
        fi

        if ! systemctl --user is-active --quiet "$unit"; then
          rm -rf "$state"
          continue
        fi

        now="$(date +%s)"
        if [ ! -f "$state/empty_since" ]; then
          printf '%s\n' "$now" > "$state/empty_since"
          continue
        fi
        empty_since="$(cat "$state/empty_since" 2>/dev/null || printf '%s\n' "$now")"
        if [ $((now - empty_since)) -lt "$idle_timeout" ]; then
          continue
        fi

        (
          flock 9
          count="$(count_clients "$state")"
          if [ "$count" -eq 0 ]; then
            systemctl --user stop "$unit" >/dev/null 2>&1 || true
            rm -rf "$state"
          fi
        ) 9>"$lock_file"
      done
    }

    cmd_status() {
      local state dir port unit pid pss count healthy
      if [ ! -d "$runtime_root" ]; then
        echo "opencode-mux: no servers"
        return 0
      fi
      for state in "$runtime_root"/*; do
        [ -d "$state" ] || continue
        [ -f "$state/port" ] || continue
        dir="$(cat "$state/dir" 2>/dev/null || true)"
        port="$(cat "$state/port" 2>/dev/null || true)"
        unit="$(cat "$state/unit" 2>/dev/null || printf 'opencode-mux@%s.service' "$(basename "$state")")"
        pid="$(systemctl --user show -p MainPID --value "$unit" 2>/dev/null || true)"
        count="$(count_clients "$state")"
        healthy="no"
        if [ -n "$port" ] && health_ok "$port"; then
          healthy="yes"
        fi
        pss=0
        if [ -n "$pid" ] && [ "$pid" != "0" ] && [ -r "/proc/$pid/smaps_rollup" ]; then
          pss="$(awk '/^Pss:/{print $2}' "/proc/$pid/smaps_rollup" 2>/dev/null || printf '0')"
        fi
        printf '%s  %s  port=%s  health=%s  clients=%s  mainPid=%s  mainPss=%sMB\n' \
          "$(basename "$state")" "$dir" "$port" "$healthy" "$count" "$pid" "$((pss / 1024))"
      done
    }

    cmd_stop() {
      local target="''${1:-}" hash state unit
      if [ -n "$target" ]; then
        hash="$(project_hash "$(realpath "$target")")"
        state="$runtime_root/$hash"
        if [ -f "$state/unit" ]; then
          unit="$(cat "$state/unit")"
          systemctl --user stop "$unit" >/dev/null 2>&1 || true
          rm -rf "$state"
        fi
        return 0
      fi

      [ -d "$runtime_root" ] || return 0
      for state in "$runtime_root"/*; do
        [ -d "$state" ] || continue
        [ -f "$state/unit" ] || continue
        unit="$(cat "$state/unit")"
        systemctl --user stop "$unit" >/dev/null 2>&1 || true
        rm -rf "$state"
      done
    }

    case "''${1:-}" in
      server)
        shift
        cmd_server "$@"
        ;;
      client)
        shift
        cmd_client "$@"
        ;;
      reap)
        shift
        cmd_reap "$@"
        ;;
      status)
        shift
        cmd_status "$@"
        ;;
      stop)
        shift
        cmd_stop "$@"
        ;;
      *)
        echo "usage: opencode-mux {client|server|reap|status|stop}" >&2
        exit 2
        ;;
    esac
  '';
}
