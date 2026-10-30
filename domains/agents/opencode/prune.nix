{
  pkgs,
  opencodePackage,
  olderThanDays,
}:

pkgs.writeShellApplication {
  name = "opencode-prune";
  runtimeInputs = with pkgs; [
    bash
    coreutils
    findutils
    gawk
    gnugrep
    jq
    sqlite
    systemd
  ];
  text = ''
    set -euo pipefail

    OLDER_DAYS=${toString olderThanDays}
    OPENCODE_BIN="${opencodePackage}/bin/opencode"
    DATA="''${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
    TMP_BASE="''${TMPDIR:-/tmp}/opencode"

    DB="$("$OPENCODE_BIN" db path 2>/dev/null || true)"
    if [ -z "''${DB:-}" ]; then
      DB="$DATA/opencode.db"
    fi

    now="$(date +%s)"
    cutoff_ms=$(( (now - OLDER_DAYS * 86400) * 1000 ))

    echo "opencode-prune: days=$OLDER_DAYS cutoff_ms=$cutoff_ms db=$DB" >&2

    # Best-effort: stop project servers so VACUUM does not fight writers.
    # Next TUI open restarts them on demand.
    if command -v systemctl >/dev/null 2>&1; then
      units="$(systemctl --user list-units --type=service --state=running --no-legend 'opencode-mux@*' 2>/dev/null | awk '{print $1}' || true)"
      if [ -n "''${units:-}" ]; then
        # shellcheck disable=SC2086
        systemctl --user stop $units >/dev/null 2>&1 || true
      fi
    fi

    # Delete sessions idle longer than cutoff across all projects.
    if [ -f "$DB" ]; then
      ids="$("$OPENCODE_BIN" db "SELECT id FROM session WHERE time_updated < $cutoff_ms" --format json 2>/dev/null | jq -r '.[]?.id // .[]? // empty' 2>/dev/null || true)"
      if [ -z "''${ids:-}" ]; then
        ids="$(sqlite3 "$DB" "PRAGMA busy_timeout=5000; SELECT id FROM session WHERE time_updated < $cutoff_ms;" 2>/dev/null || true)"
      fi
      count=0
      if [ -n "''${ids:-}" ]; then
        while IFS= read -r sid; do
          [ -n "''${sid:-}" ] || continue
          "$OPENCODE_BIN" session delete "$sid" >/dev/null 2>&1 || \
            sqlite3 "$DB" "PRAGMA busy_timeout=5000; DELETE FROM session WHERE id = '$sid';" >/dev/null 2>&1 || true
          count=$((count + 1))
        done <<< "$ids"
      fi
      echo "opencode-prune: sessions deleted: $count" >&2
    else
      echo "opencode-prune: no db at $DB, skipping session delete" >&2
    fi

    # Age out sidecar files. Log is append-only single file, so truncate.
    if [ -d "$DATA/snapshot" ]; then
      find "$DATA/snapshot" -type f -mtime +"$OLDER_DAYS" -delete 2>/dev/null || true
      find "$DATA/snapshot" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    fi
    if [ -d "$DATA/tool-output" ]; then
      find "$DATA/tool-output" -type f -mtime +"$OLDER_DAYS" -delete 2>/dev/null || true
    fi
    if [ -f "$DATA/log/opencode.log" ]; then
      truncate -s 0 "$DATA/log/opencode.log" 2>/dev/null || true
    fi
    # Stale full-copy backup plus anything old under tmp.
    rm -rf "$TMP_BASE/backup" 2>/dev/null || true
    if [ -d "$TMP_BASE" ]; then
      find "$TMP_BASE" -mindepth 1 -mtime +"$OLDER_DAYS" -exec rm -rf {} + 2>/dev/null || true
    fi

    # Reclaim freelist pages left by deletes.
    if [ -f "$DB" ]; then
      sqlite3 "$DB" "PRAGMA busy_timeout=5000; PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1 || true
      sqlite3 "$DB" "PRAGMA busy_timeout=30000; VACUUM;" >/dev/null 2>&1 || true
      sqlite3 "$DB" "PRAGMA journal_mode=WAL;" >/dev/null 2>&1 || true
    fi

    echo "opencode-prune: done" >&2
  '';
}
