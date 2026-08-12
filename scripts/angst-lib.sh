#!/usr/bin/env bash

usage() {
    cat <<'EOF'
Usage:
  angst bootstrap-secrets [--host HOST]
  angst render [--repo PATH] [--host HOST] [--theme THEME] [--reload|--no-reload]
  angst watch  [--repo PATH] [--host HOST] [--theme THEME]
  angst projects <add|sync|status|capture|edit-env|rm> ...
EOF
}

repo_root_default() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

find_host_config_dir() {
    local repo="$1" host="$2"
    for d in "$repo/hosts/"*/; do
        [ -d "$d" ] || continue
        local dn
        dn="$(basename "$d")"
        if [ -f "$repo/hosts/$dn/$host/default.nix" ]; then
            echo "$repo/hosts/$dn/$host"
            return 0
        fi
    done
    if [ -f "$repo/hosts/$host/default.nix" ]; then
        echo "$repo/hosts/$host"
        return 0
    fi
    return 1
}

config_val() {
    local repo="$1" host="$2" key="$3"
    local dir
    dir="$(find_host_config_dir "$repo" "$host")" || return 1
    nix eval --file "$dir/default.nix" --raw --apply "x: x.$key or null" 2>/dev/null || true
}

reload_hooks() {
    if command -v i3-msg >/dev/null 2>&1 && [ -n "${I3SOCK:-}" ]; then
        i3-msg reload >/dev/null || true
    fi
}
