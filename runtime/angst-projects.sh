#!/usr/bin/env bash
# Shared `angst projects` logic. Concatenated into the angst CLI (angst.sh)
# and the home-manager `angst-projects-sync` wrapper. Depends on
# `repo_root_default` from angst-lib.sh (included by both callers).

projects_usage() {
    cat <<'EOF'
Usage:
  angst projects add <name> <repo> [--scope work|personal]
  angst projects sync
  angst projects status
  angst projects capture <name>
  angst projects edit-env <name>
  angst projects rm <name>
EOF
}

# Store root: ANGST_PROJECTS_STORE (wrapper) or $REPO/projects (CLI).
projects_store_root() {
    if [ -n "${ANGST_PROJECTS_STORE:-}" ]; then
        printf '%s\n' "$ANGST_PROJECTS_STORE"
        return 0
    fi
    printf '%s/projects\n' "$(repo_root_default)"
}

# On-disk clone root: ~/projects by default.
projects_root() {
    printf '%s\n' "${ANGST_PROJECTS_ROOT:-$HOME/projects}"
}

# Scope key file: personal -> default age key, work -> work-keys.txt.
projects_keyfile() {
    case "${1:-}" in
    work) printf '%s\n' "${SOPS_WORK_AGE_KEY_FILE:-$HOME/.config/sops/age/work-keys.txt}" ;;
    *) printf '%s\n' "${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}" ;;
    esac
}

# Age public key for a scope, derived from its key file.
projects_recipient() {
    local keyfile
    keyfile="$(projects_keyfile "$1")"
    [ -f "$keyfile" ] || return 1
    age-keygen -y "$keyfile" 2>/dev/null
}

# Encrypt `plain` (a file outside the store) to `target` (inside the store)
# in sops binary format, to the scope's age key. Plaintext only ever sits in
# a temp dir outside the repo; the store never sees cleartext.
projects_encrypt() {
    local scope="$1" plain="$2" target="$3"
    local recipient keyfile work rc
    recipient="$(projects_recipient "$scope")" || return 1
    keyfile="$(projects_keyfile "$scope")"
    work="$(mktemp -d)" || return 1
    rc=1
    {
        printf -- '---\ncreation_rules:\n  - path_regex: .*\n    age: |\n      %s\n' "$recipient" >"$work/.sops.yaml"
        cp "$plain" "$work/plain"
        if (cd "$work" && SOPS_AGE_KEY_FILE="$keyfile" sops -e --input-type binary --output-type binary --output "$target" plain); then
            rc=0
        fi
    }
    rm -rf "$work"
    return $rc
}

# Decrypt a store file (sops binary) to stdout using the scope's key.
projects_decrypt() {
    local scope="$1" file="$2"
    SOPS_AGE_KEY_FILE="$(projects_keyfile "$scope")" sops -d --input-type binary --output-type binary "$file"
}

# Decrypt a store file into `out` (byte-exact: no command substitution).
projects_decrypt_to_file() {
    local scope="$1" file="$2" out="$3"
    SOPS_AGE_KEY_FILE="$(projects_keyfile "$scope")" sops -d --input-type binary --output-type binary "$file" >"$out"
}

# Resolve a project name to "<scope> <id>"; names are unique across the store.
projects_resolve() {
    local name="$1" store scope scope_dir meta key plain
    store="$(projects_store_root)"
    for scope in personal work; do
        scope_dir="$store/$scope"
        [ -d "$scope_dir" ] || continue
        key="$(projects_keyfile "$scope")"
        [ -f "$key" ] || continue
        for meta in "$scope_dir"/*/metadata.yaml; do
            [ -f "$meta" ] || continue
            if plain="$(projects_decrypt "$scope" "$meta" 2>/dev/null)" &&
                [ "$(printf '%s' "$plain" | jq -r '.name // empty')" = "$name" ]; then
                printf '%s %s\n' "$scope" "$(basename "$(dirname "$meta")")"
                return 0
            fi
        done
    done
    return 1
}

projects_add() {
    local name="" repo="" scope="personal"
    while [ "$#" -gt 0 ]; do
        case "$1" in
        --scope)
            scope="${2:-}"
            if [ "$#" -lt 2 ] || [ -z "$scope" ]; then
                echo "error: --scope requires a value (work|personal)" >&2
                projects_usage >&2
                return 2
            fi
            shift 2
            ;;
        -h | --help)
            projects_usage
            return 0
            ;;
        *)
            if [ -z "$name" ]; then
                name="$1"
            elif [ -z "$repo" ]; then
                repo="$1"
            else
                echo "error: too many arguments" >&2
                projects_usage >&2
                return 2
            fi
            shift
            ;;
        esac
    done

    if [ -z "$name" ] || [ -z "$repo" ]; then
        echo "error: add requires a name and a repo URL" >&2
        projects_usage >&2
        return 2
    fi
    case "$scope" in
    personal | work) ;;
    *)
        echo "error: invalid scope '$scope' (work|personal)" >&2
        return 2
        ;;
    esac

    local store keyfile
    store="$(projects_store_root)"
    keyfile="$(projects_keyfile "$scope")"
    if [ ! -f "$keyfile" ]; then
        echo "error: no $scope age key at $keyfile" >&2
        if [ "$scope" = "work" ]; then
            echo "  work projects need a pre-provisioned work key (provision it via the .config/sops impermanence dir). A missing work key is misprovisioning, not a bootstrap case." >&2
        fi
        return 1
    fi

    if projects_resolve "$name" >/dev/null 2>&1; then
        echo "error: project '$name' already exists in the store" >&2
        return 1
    fi
    if [ "$scope" = "personal" ] && [ ! -f "$(projects_keyfile work)" ]; then
        echo "warn: work key missing; work-scope duplicate names not checked" >&2
    fi

    local id dir tmp
    id="$(openssl rand -hex 8)"
    dir="$store/$scope/$id"
    mkdir -p "$dir" || return 1
    tmp="$(mktemp -d)" || {
        rm -rf "$dir"
        return 1
    }
    if ! jq -n --arg name "$name" --arg repo "$repo" '{name: $name, repo: $repo}' >"$tmp/metadata"; then
        rm -rf "$tmp" "$dir"
        return 1
    fi
    : >"$tmp/env"
    if ! projects_encrypt "$scope" "$tmp/metadata" "$dir/metadata.yaml" ||
        ! projects_encrypt "$scope" "$tmp/env" "$dir/env"; then
        echo "error: encryption failed for '$name' (check the $scope age key)" >&2
        rm -rf "$tmp" "$dir"
        return 1
    fi
    rm -rf "$tmp"
    echo "added project '$name' -> $scope/$id"
}

# Host selection: ANGST_PROJECTS_ONLY is a space-separated list of opaque store
# ids. Unset (manual CLI) = sync all; set-but-empty (host declared no projects)
# = sync none. Names stay encrypted; hosts reference ids only.
projects_selected() {
    local id="$1" p
    if [ -n "${ANGST_PROJECTS_ONLY+x}" ]; then
        for p in ${ANGST_PROJECTS_ONLY:-}; do
            [ "$p" = "$id" ] && return 0
        done
        return 1
    fi
    return 0
}

projects_sync() {
    local store root rc scope scope_dir key meta id plain name repo target
    store="$(projects_store_root)"
    root="$(projects_root)"
    if [ ! -d "$store" ]; then
        echo "warn: projects store not found at $store; nothing to sync" >&2
        return 0
    fi
    mkdir -p "$root" 2>/dev/null || true
    chmod 755 "$root" 2>/dev/null || true
    rc=0
    for scope in personal work; do
        scope_dir="$store/$scope"
        [ -d "$scope_dir" ] || continue
        key="$(projects_keyfile "$scope")"
        if [ ! -f "$key" ]; then
            echo "warn: no $scope age key at $key; skipping $scope projects" >&2
            continue
        fi
        for meta in "$scope_dir"/*/metadata.yaml; do
            [ -f "$meta" ] || continue
            id="$(basename "$(dirname "$meta")")"
            projects_selected "$id" || continue
            if ! plain="$(projects_decrypt "$scope" "$meta" 2>/dev/null)"; then
                echo "warn: could not decrypt $scope/$id metadata; skipping" >&2
                continue
            fi
            name="$(printf '%s' "$plain" | jq -r '.name')"
            repo="$(printf '%s' "$plain" | jq -r '.repo')"
            if [ -z "$name" ]; then
                echo "warn: empty name in $scope/$id metadata; skipping" >&2
                continue
            fi
            target="$root/$name"
            if [ ! -d "$target/.git" ]; then
                echo "cloning $repo -> $target"
                if ! timeout 120 git clone "$repo" "$target" 2>/dev/null; then
                    echo "warn: clone failed for '$name'; skipping (network down?)" >&2
                    continue
                fi
            fi
            projects_sync_env "$scope" "$id" "$name" || rc=1
        done
    done
    return $rc
}

# Sidecar-hash-tracked env materialization. Never clobbers a locally edited
# .env; marks it stale with a redacted (key-name only) diff instead.
projects_sync_env() {
    local scope="$1" id="$2" name="$3"
    local store env_file target sidecar_dir sidecar tmp store_hash cur last
    store="$(projects_store_root)"
    env_file="$store/$scope/$id/env"
    target="$(projects_root)/$name/.env"
    sidecar_dir="$HOME/.secrets/projects"
    sidecar="$sidecar_dir/$name.env.sha256"
    mkdir -p "$sidecar_dir" 2>/dev/null || true
    chmod 700 "$sidecar_dir" 2>/dev/null || true

    tmp="$(mktemp)" || return 0
    if ! projects_decrypt_to_file "$scope" "$env_file" "$tmp" 2>/dev/null; then
        echo "warn: could not decrypt $name env; skipping" >&2
        rm -f "$tmp"
        return 0
    fi
    store_hash="$(sha256sum "$tmp" | awk '{print $1}')"

    if [ ! -f "$target" ]; then
        cp "$tmp" "$target"
        chmod 600 "$target"
        printf '%s\n' "$store_hash" >"$sidecar"
        echo "materialized $name/.env"
        rm -f "$tmp"
        return 0
    fi

    cur="$(sha256sum "$target" | awk '{print $1}')"
    last=""
    [ -f "$sidecar" ] && last="$(cat "$sidecar")"

    if [ "$cur" = "$store_hash" ]; then
        printf '%s\n' "$store_hash" >"$sidecar"
        rm -f "$tmp"
        return 0
    fi

    if [ "$cur" = "$last" ]; then
        cp "$tmp" "$target"
        chmod 600 "$target"
        printf '%s\n' "$store_hash" >"$sidecar"
        echo "updated $name/.env (store changed)"
        rm -f "$tmp"
        return 0
    fi

    echo "stale: $name/.env was edited locally; not clobbering" >&2
    projects_env_key_diff "$tmp" "$target" >&2 || true
    rm -f "$tmp"
    return 1
}

# Redacted diff: only key names, never values.
projects_env_key_diff() {
    local a b
    a="$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null | cut -d= -f1 | sort -u)"
    b="$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$2" 2>/dev/null | cut -d= -f1 | sort -u)"
    if [ -n "$a" ] || [ -n "$b" ]; then
        diff <(printf '%s\n' "$a" | grep -v '^$') <(printf '%s\n' "$b" | grep -v '^$') 2>/dev/null |
            sed -e 's/^</  store: /' -e 's/^>/  local: /' || true
    fi
}

projects_status() {
    local store root scope scope_dir key meta id plain name repo target env_file sidecar
    local env_status store_hash cur last missing
    store="$(projects_store_root)"
    root="$(projects_root)"
    if [ ! -d "$store" ]; then
        echo "projects store not found at $store" >&2
        return 0
    fi
    printf '%-8s %-20s %-24s %-40s %s\n' SCOPE ID NAME REPO ENV
    for scope in personal work; do
        scope_dir="$store/$scope"
        [ -d "$scope_dir" ] || continue
        key="$(projects_keyfile "$scope")"
        if [ ! -f "$key" ]; then
            echo "warn: no $scope age key at $key; $scope projects not listed" >&2
            continue
        fi
        for meta in "$scope_dir"/*/metadata.yaml; do
            [ -f "$meta" ] || continue
            id="$(basename "$(dirname "$meta")")"
            if ! plain="$(projects_decrypt "$scope" "$meta" 2>/dev/null)"; then
                echo "warn: could not decrypt $scope/$id metadata" >&2
                continue
            fi
            name="$(printf '%s' "$plain" | jq -r '.name')"
            repo="$(printf '%s' "$plain" | jq -r '.repo')"
            target="$root/$name"
            env_status="no clone"
            if [ -d "$target/.git" ]; then
                env_file="$store/$scope/$id/env"
                sidecar="$HOME/.secrets/projects/$name.env.sha256"
                if [ ! -f "$target/.env" ]; then
                    env_status="missing"
                else
                    cur="$(sha256sum "$target/.env" | awk '{print $1}')"
                    if tmp="$(mktemp)"; then
                        if projects_decrypt_to_file "$scope" "$env_file" "$tmp" 2>/dev/null; then
                            store_hash="$(sha256sum "$tmp" | awk '{print $1}')"
                            last=""
                            [ -f "$sidecar" ] && last="$(cat "$sidecar")"
                            if [ "$cur" = "$store_hash" ]; then
                                env_status="ok"
                            elif [ "$cur" = "$last" ]; then
                                env_status="store-changed"
                            else
                                env_status="STALE"
                            fi
                        else
                            env_status="undecryptable"
                        fi
                        rm -f "$tmp"
                    fi
                fi
            fi
            printf '%-8s %-20s %-24s %-40s %s\n' "$scope" "$id" "$name" "$repo" "$env_status"
            if [ -d "$target/.git" ] && [ -f "$target/.env.example" ]; then
                missing="$(comm -23 \
                    <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$target/.env.example" 2>/dev/null | cut -d= -f1 | sort -u) \
                    <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$target/.env" 2>/dev/null | cut -d= -f1 | sort -u))"
                if [ -n "$missing" ]; then
                    echo "  .env.example vars not declared in .env: $(printf '%s' "$missing" | tr '\n' ' ')"
                fi
            fi
        done
    done
}

projects_capture() {
    local name="$1" res scope id src store target sidecar
    res="$(projects_resolve "$name" 2>/dev/null)" || {
        echo "error: unknown project '$name'" >&2
        return 1
    }
    read -r scope id <<<"$res"
    src="$(projects_root)/$name/.env"
    if [ ! -f "$src" ]; then
        echo "error: no $src to capture" >&2
        return 1
    fi
    store="$(projects_store_root)"
    target="$store/$scope/$id/env"
    if ! projects_encrypt "$scope" "$src" "$target"; then
        echo "error: encryption failed for '$name'" >&2
        return 1
    fi
    sidecar="$HOME/.secrets/projects/$name.env.sha256"
    mkdir -p "$HOME/.secrets/projects" 2>/dev/null || true
    sha256sum "$src" | awk '{print $1}' >"$sidecar"
    echo "captured $name (scope $scope)"
}

projects_edit_env() {
    local name="$1" res scope id store env_file tmp editor target sidecar cur last
    res="$(projects_resolve "$name" 2>/dev/null)" || {
        echo "error: unknown project '$name'" >&2
        return 1
    }
    read -r scope id <<<"$res"
    store="$(projects_store_root)"
    env_file="$store/$scope/$id/env"
    tmp="$(mktemp)" || return 1
    if ! projects_decrypt_to_file "$scope" "$env_file" "$tmp" 2>/dev/null; then
        echo "error: could not decrypt $name env" >&2
        rm -f "$tmp"
        return 1
    fi
    chmod 600 "$tmp"
    editor="${EDITOR:-vi}"
    if ! $editor "$tmp"; then
        echo "edit aborted; store unchanged" >&2
        rm -f "$tmp"
        return 1
    fi
    if ! projects_encrypt "$scope" "$tmp" "$env_file"; then
        echo "error: re-encryption failed; store unchanged" >&2
        rm -f "$tmp"
        return 1
    fi
    rm -f "$tmp"
    echo "re-encrypted $name env (scope $scope)"

    target="$(projects_root)/$name/.env"
    sidecar="$HOME/.secrets/projects/$name.env.sha256"
    if [ -f "$target" ] && [ -f "$sidecar" ]; then
        cur="$(sha256sum "$target" | awk '{print $1}')"
        last="$(cat "$sidecar")"
        if [ "$cur" = "$last" ]; then
            if projects_decrypt_to_file "$scope" "$env_file" "$target" 2>/dev/null; then
                chmod 600 "$target"
                sha256sum "$target" | awk '{print $1}' >"$sidecar"
                echo "resynced $name/.env"
            fi
        fi
    fi
}

projects_rm() {
    local name="$1" res scope id store
    res="$(projects_resolve "$name" 2>/dev/null)" || {
        echo "error: unknown project '$name'" >&2
        return 1
    }
    read -r scope id <<<"$res"
    store="$(projects_store_root)"
    rm -rf "${store:?}/${scope:?}/${id:?}"
    rm -f "$HOME/.secrets/projects/$name.env.sha256"
    echo "removed project '$name' ($scope/$id)"
}

angst_projects_cmd() {
    local cmd="${1:-}"
    if [ "$#" -gt 0 ]; then shift; fi
    case "$cmd" in
    add) projects_add "$@" ;;
    sync) projects_sync "$@" ;;
    status) projects_status "$@" ;;
    capture) projects_capture "$@" ;;
    edit-env) projects_edit_env "$@" ;;
    rm) projects_rm "$@" ;;
    -h | --help | "") projects_usage ;;
    *)
        echo "unknown projects command: $cmd" >&2
        projects_usage >&2
        return 2
        ;;
    esac
}
