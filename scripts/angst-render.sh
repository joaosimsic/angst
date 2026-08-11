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
