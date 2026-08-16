#!/usr/bin/env bash
# Shared `angst ftp` logic, concatenated into the ftp mount script and sourced
# by the pipeline check (checks/ftp-pipeline.nix). Parses a decrypted rclone
# .conf JSON, renders a lean rclone INI, and exports the remote/path.

# Render an rclone INI from a validated .conf JSON into "$ini" (0600) and set
# FTP_REMOTE / FTP_PATH for the caller. No secrets are echoed to stdout.
ftp_transform_config() {
    local conf="$1" ini="$2"
    FTP_REMOTE="$(jq -r '.remote' "$conf")"
    FTP_PATH="$(jq -r '.path // "/"' "$conf")"
    {
        echo "[$FTP_REMOTE]"
        jq -r '.config | to_entries[] | "\(.key) = \(.value|tostring)"' "$conf"
    } >"$ini"
    chmod 600 "$ini"
}
