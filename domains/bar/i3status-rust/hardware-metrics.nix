{ pkgs }:

pkgs.writeShellApplication {
  name = "i3-hardware-metrics";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
  ];
  text = ''
    set -euo pipefail

    runtime="''${XDG_RUNTIME_DIR:-/tmp}"
    state_file="$runtime/i3-hardware-state"
    gpu_cache="$runtime/i3-gpu-cache"

    detect_gpu() {
      gpu_pct=""
      gpu_mem_used=0
      gpu_mem_total=0

      if [ -r "$gpu_cache" ]; then
        if read -r cache_pct cache_used cache_total cache_ts < "$gpu_cache"; then
          case "$cache_ts" in
            "" | *[!0-9]*) ;;
            *)
              if (( $(date +%s) - cache_ts < 2 )); then
                if [ "$cache_pct" = "n/a" ]; then
                  gpu_pct=""
                else
                  gpu_pct=$cache_pct
                fi
                gpu_mem_used=$cache_used
                gpu_mem_total=$cache_total
                return 0
              fi
              ;;
          esac
        fi
      fi

      if command -v nvidia-smi >/dev/null 2>&1; then
        local nv
        nv=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || true)
        if [ -n "$nv" ]; then
          local best=-1 used=0 total=0 u m t
          while IFS=',' read -r u m t; do
            u="''${u//[[:space:]]/}"
            m="''${m//[[:space:]]/}"
            t="''${t//[[:space:]]/}"
            case "$u" in
              "" | *[!0-9]*) continue ;;
            esac
            if (( u > best )); then
              best=$u
              used=$m
              total=$t
            fi
          done <<< "$nv"
          if (( best >= 0 )); then
            gpu_pct=$best
            case "$used" in
              "" | *[!0-9]*) used=0 ;;
            esac
            case "$total" in
              "" | *[!0-9]*) total=0 ;;
            esac
            gpu_mem_used=$(( used * 1048576 ))
            gpu_mem_total=$(( total * 1048576 ))
          fi
        fi
      fi

      if [ -z "$gpu_pct" ]; then
        local f p dev best=-1
        for f in /sys/class/drm/card*/device/gpu_busy_percent; do
          [ -r "$f" ] || continue
          p=$(cat "$f" 2>/dev/null || true)
          case "$p" in
            "" | *[!0-9]*) continue ;;
          esac
          if (( p > best )); then
            best=$p
            dev="''${f%/gpu_busy_percent}"
            gpu_mem_used=$(cat "$dev/mem_info_vram_used" 2>/dev/null || true)
            gpu_mem_total=$(cat "$dev/mem_info_vram_total" 2>/dev/null || true)
          fi
        done
        if (( best >= 0 )); then
          gpu_pct=$best
          case "$gpu_mem_used" in
            "" | *[!0-9]*) gpu_mem_used=0 ;;
          esac
          case "$gpu_mem_total" in
            "" | *[!0-9]*) gpu_mem_total=0 ;;
          esac
        fi
      fi

      if [ -n "$gpu_pct" ]; then
        printf '%s %s %s %s\n' "$gpu_pct" "$gpu_mem_used" "$gpu_mem_total" "$(date +%s)" > "$gpu_cache" 2>/dev/null || true
      else
        printf 'n/a 0 0 %s\n' "$(date +%s)" > "$gpu_cache" 2>/dev/null || true
      fi
    }

    gpu_percent() {
      detect_gpu
      if [ -n "$gpu_pct" ]; then
        printf '%s\n' "$gpu_pct"
      else
        printf 'n/a\n'
      fi
    }

    gpu_mem() {
      detect_gpu
      if (( gpu_mem_total > 0 )); then
        awk -v u="$gpu_mem_used" -v t="$gpu_mem_total" 'BEGIN { printf "%.1f/%.1f GiB", u / 1073741824, t / 1073741824 }'
      fi
    }

    case "''${1:-}" in
      --gpu-percent)
        gpu_percent
        exit 0
        ;;
      --gpu-mem)
        gpu_mem
        exit 0
        ;;
      --gpu-percent-padded)
        pct=$(gpu_percent)
        printf '%3s\n' "$pct"
        exit 0
        ;;
      "")
        ;;
      *)
        echo "usage: i3-hardware-metrics [--gpu-percent|--gpu-percent-padded|--gpu-mem]" >&2
        exit 2
        ;;
    esac

    cpu_pct=0
    read -r _ u n s i w irq sirq steal _ < /proc/stat
    total1=$((u + n + s + i + w + irq + sirq + steal))
    idle1=$((i + w))
    sleep 0.2
    read -r _ u n s i w irq sirq steal _ < /proc/stat
    total2=$((u + n + s + i + w + irq + sirq + steal))
    idle2=$((i + w))
    delta_total=$((total2 - total1))
    delta_idle=$((idle2 - idle1))
    if (( delta_total > 0 )); then
      cpu_pct=$(( (delta_total - delta_idle) * 100 / delta_total ))
    fi

    mem_total=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
    mem_avail=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
    mem_total="''${mem_total:-0}"
    mem_avail="''${mem_avail:-0}"
    if (( mem_avail == 0 )); then
      mem_avail=$(awk '/^MemFree:|^Buffers:|^Cached:/ { sum += $2 } END { print sum }' /proc/meminfo)
    fi
    mem_pct=0
    if (( mem_total > 0 )); then
      mem_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))
    fi

    disk_used=0
    disk_total=0
    for mp in /boot /state /home; do
      [ -d "$mp" ] || continue
      if read -r used size < <(df -B1 --output=used,size "$mp" 2>/dev/null | awk 'NR == 2 { print $1, $2 }'); then
        case "$used" in
          "" | *[!0-9]*) continue ;;
        esac
        case "$size" in
          "" | *[!0-9]*) continue ;;
        esac
        disk_used=$((disk_used + used))
        disk_total=$((disk_total + size))
      fi
    done
    disk_pct=""
    if (( disk_total > 0 )); then
      disk_pct=$(( disk_used * 100 / disk_total ))
    fi

    detect_gpu

    state="Idle"
    severity=0
    consider() {
      local pct=$1 warn=$2 crit=$3
      if (( pct >= crit )); then
        if (( severity < 2 )); then
          severity=2
          state="Critical"
        fi
      elif (( pct >= warn )); then
        if (( severity < 1 )); then
          severity=1
          state="Warning"
        fi
      fi
    }

    consider "$cpu_pct" 75 90
    consider "$mem_pct" 75 90
    if [ -n "$disk_pct" ]; then
      consider "$disk_pct" 75 90
    fi
    if [ -n "$gpu_pct" ]; then
      consider "$gpu_pct" 90 98
    fi

    max_pct=-1
    max_label=""
    update_max() {
      local pct=$1 label=$2
      if (( pct > max_pct )); then
        max_pct=$pct
        max_label=$label
      fi
    }
    update_max "$cpu_pct" CPU
    update_max "$mem_pct" RAM
    if [ -n "$disk_pct" ]; then
      update_max "$disk_pct" DISK
    fi
    if [ -n "$gpu_pct" ]; then
      update_max "$gpu_pct" GPU
    fi
    if (( max_pct < 0 )); then
      max_pct=0
      max_label="CPU"
    fi

    printf '%s %s\n' "$state" "$(date +%s)" > "$state_file" 2>/dev/null || true
    printf '{"text":"%s %s%%","state":"%s"}\n' "$max_label" "$max_pct" "$state"
  '';
}
