#!/usr/bin/env bash

usage() {
    cat <<'EOF'
Usage:
  angst bootstrap-secrets [--host HOST]
  angst render [--repo PATH] [--host HOST] [--theme THEME] [--reload|--no-reload]
  angst watch  [--repo PATH] [--host HOST] [--theme THEME]
EOF
}

repo_root_default() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

config_val() {
    local repo="$1" host="$2" key="$3"
    local cfg_path=""
    for d in "$repo/hosts/"*/; do
        [ -d "$d" ] || continue
        local dn
        dn="$(basename "$d")"
        if [ -f "$repo/hosts/$dn/$host/default.nix" ]; then
            cfg_path="$repo/hosts/$dn/$host/default.nix"
            break
        fi
    done
    if [ -z "$cfg_path" ] && [ -f "$repo/hosts/$host/default.nix" ]; then
        cfg_path="$repo/hosts/$host/default.nix"
    fi
    [ -n "$cfg_path" ] || return 1
    nix eval --file "$cfg_path" --raw --apply "x: x.$key or null" 2>/dev/null || true
}

reload_hooks() {
    if command -v i3-msg >/dev/null 2>&1 && [ -n "${I3SOCK:-}" ]; then
        i3-msg reload >/dev/null || true
    fi
}

bootstrap_secrets_cmd() {
    local repo_root host_name="nixos"
    repo_root="$(repo_root_default)"

    while [ "$#" -gt 0 ]; do
        case "$1" in
        --host)
            host_name="$2"
            shift 2
            ;;
        -h | --help)
            usage
            return 0
            ;;
        *)
            echo "unknown bootstrap-secrets option: $1" >&2
            usage >&2
            return 2
            ;;
        esac
    done

    if ! command -v sops >/dev/null 2>&1; then
        echo "Error: sops is not available. Install it first (e.g., nix shell nixpkgs#sops)" >&2
        return 1
    fi

    if ! command -v mkpasswd >/dev/null 2>&1; then
        echo "Error: mkpasswd is not available. Install whois or use nix environment." >&2
        return 1
    fi

    local domain="" secrets_file config_file
    for d in "$repo_root/hosts/"*/; do
        [ -d "$d" ] || continue
        local dn
        dn="$(basename "$d")"
        if [ -f "$repo_root/hosts/$dn/$host_name/default.nix" ]; then
            domain="$dn"
            break
        fi
    done

    if [ -n "$domain" ]; then
        secrets_file="$repo_root/hosts/$domain/$host_name/secrets.yaml"
        config_file="$repo_root/hosts/$domain/$host_name/default.nix"
    else
        secrets_file="$repo_root/hosts/$host_name/secrets.yaml"
        config_file="$repo_root/hosts/$host_name/default.nix"
    fi

    if [ ! -f "$config_file" ]; then
        echo "Error: host config not found for '$host_name'" >&2
        return 1
    fi

    printf "Master password: "
    read -rs master_password
    printf "\n"

    if [ -z "$master_password" ]; then
        echo "Error: password cannot be empty" >&2
        return 1
    fi

    printf "Confirm master password: "
    read -rs confirm
    printf "\n"

    if [ "$master_password" != "$confirm" ]; then
        echo "Error: passwords do not match" >&2
        return 1
    fi
    unset confirm

    local hash
    hash="$(mkpasswd -m sha-512 "$master_password")" || {
        echo "Error: failed to hash password" >&2
        return 1
    }

    if [ -f "$secrets_file" ]; then
        echo "masterPassword: \"$master_password\"" | sops --input-type yaml --output-type yaml "$secrets_file" 2>/dev/null || {
            echo "Error: failed to update $secrets_file" >&2
            return 1
        }
    else
        echo "masterPassword: \"$master_password\"" | sops --input-type yaml --output-type yaml "$secrets_file" 2>/dev/null || {
            echo "Error: failed to create $secrets_file" >&2
            return 1
        }
    fi

    if grep -q '^\s*password\s*=' "$config_file"; then
        sed -i "s|^\s*password\s*=.*|  password = \"$hash\";|" "$config_file"
    else
        sed -i "/^\s*};/i\  password = \"$hash\";" "$config_file"
    fi

    unset master_password hash

    echo "Secrets bootstrapped for $host_name:"
    echo "  secrets: $secrets_file"
    echo "  hash:    $config_file"
    echo ""
    echo "Run 'sudo nixos-rebuild switch --flake .#$host_name' to apply."
}

render_cmd() {
    local repo_root host_name theme_name=""
    repo_root="$(repo_root_default)"
    host_name="${NIX_DEFAULT_TARGET_HOST:-${ANGST_HOST:-nixos}}"
    local should_reload=1

    while [ "$#" -gt 0 ]; do
        case "$1" in
        --repo)
            repo_root="$2"
            shift 2
            ;;
        --host)
            host_name="$2"
            shift 2
            ;;
        --theme)
            theme_name="$2"
            shift 2
            ;;
        --reload)
            should_reload=1
            shift
            ;;
        --no-reload)
            should_reload=0
            shift
            ;;
        -h | --help)
            usage
            return 0
            ;;
        *)
            echo "unknown render option: $1" >&2
            usage >&2
            return 2
            ;;
        esac
    done

    if [ -z "$theme_name" ]; then
        theme_name="$(config_val "$repo_root" "$host_name" "theme")"
        theme_name="${theme_name:-monochrome}"
    fi

    if [ ! -d "$repo_root/domains" ]; then
        echo "domains directory not found under $repo_root" >&2
        return 1
    fi

    local theme_found=
    for f in "$repo_root/themes/"*.nix; do
        [ -f "$f" ] || continue
        local base
        base="$(basename "$f" .nix)"
        [ "$base" = "default" ] || [ "$base" = "schema" ] && continue
        if [ "$base" = "$theme_name" ]; then
            theme_found=1
            break
        fi
    done

    if [ -z "$theme_found" ]; then
        echo "Unknown theme '$theme_name'. Available themes:" >&2
        for f in "$repo_root/themes/"*.nix; do
            [ -f "$f" ] || continue
            local base
            base="$(basename "$f" .nix)"
            [ "$base" = "default" ] || [ "$base" = "schema" ] && continue
            echo "  $base" >&2
        done
        return 1
    fi

    echo "Evaluating templates in a single optimized batch..."
    local json_data
    json_data=$(nix eval "$repo_root#lib.renderDomainOutputsFor" \
        --apply "f: builtins.toJSON (map (o: { path = o.path; text = o.text; }) (f \"$theme_name\"))" --raw)

    while IFS= read -r path; do
        [ -n "$path" ] || continue
        local output="$repo_root/$path"
        mkdir -p "$(dirname "$output")"
        echo "$json_data" | jq -r ".[] | select(.path == \"$path\") | .text" >"$output"
        chmod u+w "$output"
        echo "rendered $path"
    done < <(echo "$json_data" | jq -r '.[] | .path')

    local unique_dirs
    unique_dirs=$(echo "$json_data" | jq -r '.[] | .path' | while IFS= read -r p; do
        echo "$p" | cut -d/ -f1-4
    done | sort -u)

    if [ -n "$unique_dirs" ]; then
        for config_dir in $unique_dirs; do
            local rel_paths
            rel_paths=$(echo "$json_data" | jq -r '.[] | .path' | while IFS= read -r p; do
                case "$p" in
                "$config_dir/"*) echo "${p#"$config_dir"/}" ;;
                esac
            done | sort -u)

            local gitignore_path="$repo_root/$config_dir/.gitignore"
            if [ -f "$gitignore_path" ]; then
                local combined
                combined=$(printf '%s\n%s' "$rel_paths" "$(cat "$gitignore_path")" | sort -u)
                printf '%s\n' "$combined" >"$gitignore_path"
            else
                printf '%s\n' "$rel_paths" >"$gitignore_path"
            fi
            echo "synced $config_dir/.gitignore"
        done
    fi

    if [ "$should_reload" -eq 1 ]; then
        reload_hooks
    fi
}

watch_cmd() {
    local repo_root host_name theme_name="${ANGST_THEME:-}"
    repo_root="$(repo_root_default)"
    host_name="${NIX_DEFAULT_TARGET_HOST:-${ANGST_HOST:-nixos}}"

    while [ "$#" -gt 0 ]; do
        case "$1" in
        --repo)
            repo_root="$2"
            shift 2
            ;;
        --host)
            host_name="$2"
            shift 2
            ;;
        --theme)
            theme_name="$2"
            shift 2
            ;;
        -h | --help)
            usage
            return 0
            ;;
        *)
            echo "unknown watch option: $1" >&2
            usage >&2
            return 2
            ;;
        esac
    done

    local args=(render --repo "$repo_root" --host "$host_name" --reload)
    if [ -n "$theme_name" ]; then args+=(--theme "$theme_name"); fi

    local watch_path="$repo_root/hosts/$host_name"
    for d in "$repo_root/hosts/"*/; do
        [ -d "$d" ] || continue
        local dn
        dn="$(basename "$d")"
        if [ -f "$repo_root/hosts/$dn/$host_name/default.nix" ]; then
            watch_path="$repo_root/hosts/$dn/$host_name"
            break
        fi
    done

    watchexec \
        --watch "$repo_root/themes" \
        --watch "$repo_root/domains" \
        --watch "$watch_path" \
        -- "$0" "${args[@]}"
}

command="${1:-}"
if [ "$#" -gt 0 ]; then shift; fi

case "$command" in
bootstrap-secrets) bootstrap_secrets_cmd "$@" ;;
render) render_cmd "$@" ;;
watch) watch_cmd "$@" ;;
-h | --help | "") usage ;;
*)
    echo "unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
