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
    local resolved
    resolved="$(find_host_config_dir "$repo_root" "$host_name")" && watch_path="$resolved"

    watchexec \
        --watch "$repo_root/themes" \
        --watch "$repo_root/domains" \
        --watch "$watch_path" \
        -- "$0" "${args[@]}"
}
