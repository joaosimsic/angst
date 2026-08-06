#!/usr/bin/env bash

usage() {
    cat <<'EOF'
Usage:
  angst passwd
  angst render [--repo PATH] [--host HOST] [--theme THEME] [--reload|--no-reload]
  angst watch  [--repo PATH] [--host HOST] [--theme THEME]
EOF
}

repo_root_default() {
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/local/config.nix" ]; then
            printf '%s\n' "$dir"
            return
        fi
        dir="$(dirname "$dir")"
    done
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

config_val() {
    local repo="$1" key="$2"
    nix eval --impure --expr "(import $repo/local/config.nix).$key" --raw 2>/dev/null || true
}

reload_hooks() {
    if command -v i3-msg >/dev/null 2>&1 && [ -n "${I3SOCK:-}" ]; then
        i3-msg reload >/dev/null || true
    fi
}

passwd_cmd() {
    local repo_root
    repo_root="$(repo_root_default)"
    local config_file="$repo_root/local/config.nix"

    if [ ! -f "$config_file" ]; then
        echo "Error: $config_file not found" >&2
        echo "Copy local/config.nix.example to local/config.nix and fill in your values first." >&2
        return 1
    fi

    printf "Password: "
    read -rs password
    printf "\n"

    if [ -z "$password" ]; then
        echo "Error: password cannot be empty" >&2
        return 1
    fi

    printf "Confirm password: "
    read -rs password_confirm
    printf "\n"

    if [ "$password" != "$password_confirm" ]; then
        echo "Error: passwords do not match" >&2
        return 1
    fi

    local hash
    hash="$(mkpasswd -m sha-512 "$password")" || {
        echo "Error: failed to hash password (is mkpasswd available?)" >&2
        return 1
    }
    unset password password_confirm

    if grep -q "^[[:space:]]*password[[:space:]]*=" "$config_file"; then
        sed -i "s|^[[:space:]]*password[[:space:]]*=.*$|  password = \"$hash\";|" "$config_file"
    else
        echo "Error: could not find 'password' field in $config_file" >&2
        return 1
    fi

    echo "Password hashed and written to $config_file"
}

render_cmd() {
    local repo_root
    repo_root="$(repo_root_default)"
    local host_name
    host_name="$(config_val "$repo_root" "hostname")"
    host_name="${host_name:-${ANGST_HOST:-personal}}"
    local theme_name=""
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
        theme_name="$(config_val "$repo_root" "theme")"
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
    json_data=$(nix eval --impure "$repo_root#lib.renderDomainOutputsFor" \
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
    local repo_root
    repo_root="$(repo_root_default)"
    local host_name
    host_name="$(config_val "$repo_root" "hostname")"
    host_name="${host_name:-${ANGST_HOST:-personal}}"
    local theme_name="${ANGST_THEME:-}"

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
    if [ -n "$theme_name" ]; then
        args+=(--theme "$theme_name")
    fi

    watchexec \
        --watch "$repo_root/themes" \
        --watch "$repo_root/domains" \
        --watch "$repo_root/local" \
        -- "$0" "${args[@]}"
}

command="${1:-}"
if [ "$#" -gt 0 ]; then
    shift
fi

case "$command" in
passwd)
    passwd_cmd "$@"
    ;;
render)
    render_cmd "$@"
    ;;
watch)
    watch_cmd "$@"
    ;;
-h | --help | "")
    usage
    ;;
*)
    echo "unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
