usage() {
  cat <<'EOF'
Usage:
  angst render [--repo PATH] [--host HOST] [--theme THEME] [--reload|--no-reload]
  angst watch  [--repo PATH] [--host HOST] [--theme THEME]
EOF
}

repo_root_default() {
  if [ -n "${ANGST_REPO:-}" ]; then
    printf '%s\n' "$ANGST_REPO"
  elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    pwd
  fi
}

theme_default() {
  local repo_root="$1"
  local host_name="$2"
  if [ -n "${ANGST_THEME:-}" ]; then
    printf '%s\n' "$ANGST_THEME"
  else
    nix eval --impure --raw --expr "let host = import ${repo_root}/hosts/${host_name}; in builtins.toString (host.theme or \"monochrome\")"
  fi
}

reload_hooks() {
  if command -v i3-msg >/dev/null 2>&1 && [ -n "${I3SOCK:-}" ]; then
    i3-msg reload >/dev/null || true
  fi
}

render_cmd() {
  local repo_root
  repo_root="$(repo_root_default)"
  local host_name="${ANGST_HOST:-personal}"
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
      -h|--help)
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
    theme_name="$(theme_default "$repo_root" "$host_name")"
  fi

  if [ ! -d "$repo_root/domains" ]; then
    echo "domains directory not found under $repo_root" >&2
    return 1
  fi

  echo "Evaluating templates in a single optimized batch..."
  local json_data
  json_data=$(nix eval --impure "$repo_root#lib.renderDomainOutputsFor" \
    --apply "f: builtins.toJSON (f \"$host_name\" \"$theme_name\")" --raw)

  while IFS= read -r path; do
      [ -n "$path" ] || continue
      local output="$repo_root/$path"
      mkdir -p "$(dirname "$output")"

      echo "$json_data" | jq -r ".[] | select(.path == \"$path\") | .text" > "$output"

      chmod u+w "$output"
      echo "rendered $path"
  done < <(echo "$json_data" | jq -r '.[] | .path')

  if [ "$should_reload" -eq 1 ]; then
    reload_hooks
  fi
}

watch_cmd() {
  local repo_root
  repo_root="$(repo_root_default)"
  local host_name="${ANGST_HOST:-personal}"
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
      -h|--help)
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
    --watch "$repo_root/hosts/$host_name" \
    -- "$0" "${args[@]}"
}

command="${1:-}"
if [ "$#" -gt 0 ]; then
  shift
fi

case "$command" in
  render)
    render_cmd "$@"
    ;;
  watch)
    watch_cmd "$@"
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    echo "unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
