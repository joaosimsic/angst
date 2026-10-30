{ pkgs }:

pkgs.writeShellApplication {
  name = "i3-network-metrics";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.iproute2
    pkgs.iw
    pkgs.jq
  ];
  text = ''
    set -euo pipefail

    runtime="''${XDG_RUNTIME_DIR:-/tmp}"
    state_file="$runtime/i3-network-state"
    stats_file="$runtime/i3-network-details-stats"
    sep="—"

    iface_ipv4() {
      local iface=$1
      ip -4 -o addr show dev "$iface" scope global 2>/dev/null \
        | awk 'NR == 1 { sub(/\/.*/, "", $4); print $4 }'
    }

    is_wireless() {
      local iface=$1
      [ -d "/sys/class/net/$iface/wireless" ] || [ -e "/sys/class/net/$iface/phy80211" ]
    }

    vpn_iface() {
      local dev name flags ip
      for dev in /sys/class/net/*; do
        [ -e "$dev" ] || continue
        name="''${dev##*/}"
        case "$name" in
          tun* | tap* | wg* | ppp* | tailscale* | vpn*) ;;
          *)
            if [ -e "$dev/tun_flags" ] || [[ "$(cat "$dev/uevent" 2>/dev/null || true)" == *wireguard* ]]; then
              :
            else
              continue
            fi
            ;;
        esac
        flags=$(cat "$dev/flags" 2>/dev/null || printf '0x0')
        (( flags & 1 )) || continue
        ip=$(iface_ipv4 "$name")
        if [ -n "$ip" ]; then
          printf '%s %s\n' "$name" "$ip"
          return 0
        fi
      done
      return 1
    }

    default_iface() {
      ip route show default 2>/dev/null \
        | awk '/^default/ { for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
    }

    gateway_ip() {
      ip route show default 2>/dev/null \
        | awk '/^default/ { for (i = 1; i <= NF; i++) if ($i == "via") { print $(i + 1); exit } }'
    }

    active_connection() {
      local vpn name ip
      if vpn=$(vpn_iface); then
        name="''${vpn%% *}"
        ip="''${vpn#* }"
        printf 'vpn %s %s\n' "$name" "$ip"
        return 0
      fi
      name=$(default_iface)
      if [ -n "$name" ]; then
        ip=$(iface_ipv4 "$name")
        if is_wireless "$name"; then
          printf 'wireless %s %s\n' "$name" "$ip"
        else
          printf 'wired %s %s\n' "$name" "$ip"
        fi
        return 0
      fi
      return 1
    }

    wifi_fields() {
      local iface=$1 link ssid signal freq bitrate
      link=$(iw dev "$iface" link 2>/dev/null || true)
      ssid=$(printf '%s\n' "$link" | awk '/^[[:space:]]*SSID:/ { sub(/^[[:space:]]*SSID:[[:space:]]*/, ""); print; exit }')
      signal=$(printf '%s\n' "$link" | awk '/signal:/ { print $2; exit }')
      freq=$(printf '%s\n' "$link" | awk '/freq:/ { print $2; exit }')
      bitrate=$(printf '%s\n' "$link" | awk '/tx bitrate:/ { print $3 " " $4; exit }')
      wifi_ssid=$ssid
      wifi_signal_dbm=$signal
      wifi_signal_pct=""
      wifi_freq=$freq
      wifi_bitrate=$bitrate
      if [ -n "$signal" ]; then
        case "$signal" in
          *[!0-9-]*) signal="" ;;
        esac
      fi
      if [ -n "$signal" ]; then
        wifi_signal_pct=$(( 2 * (signal + 100) ))
        (( wifi_signal_pct < 0 )) && wifi_signal_pct=0
        (( wifi_signal_pct > 100 )) && wifi_signal_pct=100
      fi
    }

    wifi_state() {
      if [ -z "''${wifi_signal_pct:-}" ]; then
        printf 'Idle\n'
      elif (( wifi_signal_pct <= 20 )); then
        printf 'Critical\n'
      elif (( wifi_signal_pct <= 35 )); then
        printf 'Warning\n'
      else
        printf 'Idle\n'
      fi
    }

    connection_state() {
      local kind=$1
      if [ "$kind" = "wireless" ]; then
        wifi_state
      else
        printf 'Idle\n'
      fi
    }

    icon_for() {
      case "$1" in
        vpn) printf 'net_vpn\n' ;;
        wireless) printf 'net_wifi\n' ;;
        wired) printf 'net_wired\n' ;;
        *) printf 'net_offline\n' ;;
      esac
    }

    write_state() {
      printf '%s %s\n' "$1" "$(date +%s)" > "$state_file" 2>/dev/null || true
    }

    jq_out() {
      jq -cn --arg icon "$1" --arg state "$2" \
        '{icon: $icon, text: "", state: $state}'
    }

    summary() {
      local kind iface ip state
      if ! read -r kind iface ip < <(active_connection); then
        write_state "Critical"
        jq_out "net_offline" "Critical"
        return
      fi
      if [ "$kind" = "wireless" ]; then
        wifi_fields "$iface"
      fi
      state=$(connection_state "$kind")
      write_state "$state"
      jq_out "$(icon_for "$kind")" "$state"
    }

    dns_servers() {
      awk '/^[[:space:]]*nameserver[[:space:]]/ { if (out != "") out = out ", "; out = out $2 } END { if (out != "") print out }' /etc/resolv.conf 2>/dev/null || true
    }

    human_bytes() {
      awk -v b="$1" 'BEGIN {
        split("B KiB MiB GiB TiB", units, " ");
        i = 1;
        while (b >= 1024 && i < 5) {
          b /= 1024;
          i++;
        }
        if (i == 1) {
          printf "%.0f%s", b, units[i];
        } else {
          printf "%.1f%s", b, units[i];
        }
      }'
    }

    sample_speed() {
      local iface=$1 rx tx now prev_iface prev_rx prev_tx prev_ts
      rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || printf '0')
      tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || printf '0')
      now=$(date +%s)
      speed_down=0
      speed_up=0
      if [ -r "$stats_file" ]; then
        if read -r prev_iface prev_rx prev_tx prev_ts < "$stats_file"; then
          case "$prev_rx$prev_tx$prev_ts" in
            *[!0-9]*) ;;
            *)
              if [ "$prev_iface" = "$iface" ] && (( now > prev_ts )) && (( rx >= prev_rx )) && (( tx >= prev_tx )); then
                speed_down=$(( (rx - prev_rx) / (now - prev_ts) ))
                speed_up=$(( (tx - prev_tx) / (now - prev_ts) ))
              fi
              ;;
          esac
        fi
      fi
      printf '%s %s %s %s\n' "$iface" "$rx" "$tx" "$now" > "$stats_file" 2>/dev/null || true
    }

    sanitize() {
      printf '%s' "$1" | awk '{ gsub(/\$/, "$$"); print }'
    }

    details_line() {
      printf '\x24{color0}%s\x24{color}\x24{goto 110}%s\n' "$1" "$(sanitize "$2")"
    }

    details() {
      local kind iface ip state type gateway dns freq
      if ! read -r kind iface ip < <(active_connection); then
        write_state "Critical"
        details_line "STATUS" "offline"
        details_line "TYPE" "offline"
        return
      fi
      case "$kind" in
        vpn) type="VPN" ;;
        wireless) type="Wi-Fi" ;;
        wired) type="Wired" ;;
      esac
      if [ "$kind" = "wireless" ]; then
        wifi_fields "$iface"
      fi
      state=$(connection_state "$kind")
      write_state "$state"
      gateway=$(gateway_ip)
      dns=$(dns_servers)
      sample_speed "$iface"
      details_line "STATUS" "connected"
      details_line "TYPE" "$type"
      details_line "IFACE" "$iface"
      details_line "ADDRESS" "''${ip:-$sep}"
      details_line "SSID" "''${wifi_ssid:-$sep}"
      if [ -n "''${wifi_signal_pct:-}" ] && [ -n "''${wifi_signal_dbm:-}" ]; then
        details_line "SIGNAL" "$wifi_signal_pct% ($wifi_signal_dbm dBm)"
      else
        details_line "SIGNAL" "$sep"
      fi
      if [ -n "''${wifi_freq:-}" ]; then
        freq=$(awk -v f="$wifi_freq" 'BEGIN { printf "%.2f GHz", f / 1000 }')
        details_line "FREQ" "$freq"
      else
        details_line "FREQ" "$sep"
      fi
      details_line "BITRATE" "''${wifi_bitrate:-$sep}"
      details_line "GATEWAY" "''${gateway:-$sep}"
      details_line "DNS" "''${dns:-$sep}"
      details_line "DOWN" "$(human_bytes "$speed_down")/s"
      details_line "UP" "$(human_bytes "$speed_up")/s"
    }

    case "''${1:-}" in
      --details)
        details
        ;;
      "")
        summary
        ;;
      *)
        echo "usage: i3-network-metrics [--details]" >&2
        exit 2
        ;;
    esac
  '';
}
