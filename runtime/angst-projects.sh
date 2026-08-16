#!/usr/bin/env bash
# Shared `angst projects` logic. Concatenated into the angst CLI (angst.sh)
# and the home-manager `angst-projects-sync` wrapper.
#
# Three layers:
#   working store  ~/.secrets/projects  -- decrypted plaintext metadata+env
#   repo store     <repo>/projects            -- sops-binary encrypted transport
#   clone root     ~/projects/<name>          -- cloned repo + decrypted .env
# Runtime ops read the working store directly (no sops). The repo store is only
# written by `angst projects export` and read by `import` / the build seed.

projects_usage() {
    cat <<'EOF'
Usage:
  angst projects add <name> <repo> [--scope work|personal]
  angst projects sync
  angst projects status
  angst projects capture <name>
  angst projects edit-env <name>
  angst projects import [--all]
  angst projects export [--all]
  angst projects rm <name>
EOF
}

# Working store root (decrypted): ANGST_PROJECTS_STORE or ~/.secrets/projects.
projects_store_root() {
    if [ -n "${ANGST_PROJECTS_STORE:-}" ]; then
        printf '%s\n' "$ANGST_PROJECTS_STORE"
        return 0
    fi
    printf '%s\n' "${ANGST_PROJECTS_STORE_DEFAULT:-$HOME/.secrets/projects}"
}

# Repo store root (encrypted): ANGST_PROJECTS_REPO or $REPO/projects (git root).
projects_repo_root() {
    if [ -n "${ANGST_PROJECTS_REPO:-}" ]; then
        printf '%s\n' "$ANGST_PROJECTS_REPO"
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

projects_sshkeyfile() {
    case "${1:-}" in
    work) printf '%s\n' "${ANGST_WORK_SSH_KEY:-$HOME/.ssh/work_ed25519}" ;;
    *) printf '%s\n' "${ANGST_SSH_KEY:-$HOME/.ssh/id_ed25519}" ;;
    esac
}

# Age public key for a scope, derived from its key file.
projects_recipient() {
    local keyfile
    keyfile="$(projects_keyfile "$1")"
    [ -f "$keyfile" ] || return 1
    age-keygen -y "$keyfile" 2>/dev/null
}

# Encrypt `plain` (a file outside the repo store) to `target` (inside the repo
# store) in sops binary format, to the scope's age key. Plaintext only ever
# sits in a temp dir outside the repo store; it never sees cleartext.
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

# Decrypt a repo store file (sops binary) to stdout using the scope's key.
projects_decrypt() {
    local scope="$1" file="$2"
    SOPS_AGE_KEY_FILE="$(projects_keyfile "$scope")" sops -d --input-type binary --output-type binary "$file"
}

# Decrypt a repo store file into `out` (byte-exact: no command substitution).
projects_decrypt_to_file() {
    local scope="$1" file="$2" out="$3"
    SOPS_AGE_KEY_FILE="$(projects_keyfile "$scope")" sops -d --input-type binary --output-type binary "$file" >"$out"
}

# Resolve a project name to "<scope> <id>" within the working store; names are
# unique across the store.
projects_resolve() {
    local name="$1" store scope scope_dir meta
    store="$(projects_store_root)"
    for scope in personal work; do
        scope_dir="$store/$scope"
        [ -d "$scope_dir" ] || continue
        for meta in "$scope_dir"/*/metadata.yaml; do
            [ -f "$meta" ] || continue
            if [ "$(jq -r '.name // empty' "$meta")" = "$name" ]; then
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

    if projects_resolve "$name" >/dev/null 2>&1; then
        echo "error: project '$name' already exists in the store" >&2
        return 1
    fi

    local store id dir
    store="$(projects_store_root)"
    id="$(openssl rand -hex 8)"
    dir="$store/$scope/$id"
    mkdir -p "$dir" || return 1
    if ! jq -n --arg name "$name" --arg repo "$repo" '{name: $name, repo: $repo}' >"$dir/metadata.yaml"; then
        rm -rf "$dir"
        return 1
    fi
    : >"$dir/env"
    echo "added project '$name' -> $scope/$id"
    echo "  (run 'angst projects export' to push it to the encrypted repo store)"
}

# Host selection: ANGST_PROJECTS_ONLY is a space-separated list of opaque store
# ids. Unset (manual CLI) = all; set-but-empty (host declared no projects) = none.
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

# Seed/import one project from the repo store into the working store (decrypt).
projects_import_one() {
    local scope="$1" id="$2"
    local store repo meta plain
    store="$(projects_store_root)"
    repo="$(projects_repo_root)"
    meta="$repo/$scope/$id/metadata.yaml"
    [ -f "$meta" ] || return 0
    local dir="$store/$scope/$id"
    mkdir -p "$dir" || return 0
    if ! plain="$(projects_decrypt "$scope" "$meta" 2>/dev/null)"; then
        echo "warn: could not decrypt $scope/$id metadata; skipping" >&2
        return 0
    fi
    printf '%s\n' "$plain" >"$dir/metadata.yaml"
    chmod 600 "$dir/metadata.yaml"
    if [ -f "$repo/$scope/$id/env" ]; then
        if projects_decrypt_to_file "$scope" "$repo/$scope/$id/env" "$dir/env" 2>/dev/null; then
            chmod 600 "$dir/env"
        else
            echo "warn: could not decrypt $scope/$id env; skipping" >&2
        fi
    else
        : >"$dir/env"
        chmod 600 "$dir/env"
    fi
    echo "imported $scope/$id"
}

# Import the repo store into the working store (decrypt). Without --all only
# host-selected ids are imported (and only those missing locally are written).
projects_import() {
    local all=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
        --all) all=1 ;;
        -h | --help)
            projects_usage
            return 0
            ;;
        *)
            echo "unknown import option: $1" >&2
            projects_usage >&2
            return 2
            ;;
        esac
        shift
    done

    local store repo scope scope_dir meta id
    store="$(projects_store_root)"
    repo="$(projects_repo_root)"
    if [ ! -d "$repo" ]; then
        echo "warn: repo store not found at $repo; nothing to import" >&2
        return 0
    fi
    mkdir -p "$store" 2>/dev/null || true
    chmod 700 "$store" 2>/dev/null || true
    for scope in personal work; do
        scope_dir="$repo/$scope"
        [ -d "$scope_dir" ] || continue
        [ -f "$(projects_keyfile "$scope")" ] || {
            echo "warn: no $scope age key; skipping $scope import" >&2
            continue
        }
        for meta in "$scope_dir"/*/metadata.yaml; do
            [ -f "$meta" ] || continue
            id="$(basename "$(dirname "$meta")")"
            [ "$all" -eq 1 ] || projects_selected "$id" || continue
            if [ -f "$store/$scope/$id/metadata.yaml" ]; then
                continue # never clobber an existing working entry
            fi
            projects_import_one "$scope" "$id"
        done
    done
}

# Export the working store into the repo store (encrypt). This is the ONLY
# writer of the repo store. Without --all only host-selected ids are exported.
projects_export() {
    local all=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
        --all) all=1 ;;
        -h | --help)
            projects_usage
            return 0
            ;;
        *)
            echo "unknown export option: $1" >&2
            projects_usage >&2
            return 2
            ;;
        esac
        shift
    done

    local store repo scope scope_dir meta id plain
    store="$(projects_store_root)"
    repo="$(projects_repo_root)"
    if [ ! -d "$store" ]; then
        echo "warn: working store not found at $store; nothing to export" >&2
        return 0
    fi
    mkdir -p "$repo" 2>/dev/null || true
    rc=0
    for scope in personal work; do
        scope_dir="$store/$scope"
        [ -d "$scope_dir" ] || continue
        [ -f "$(projects_keyfile "$scope")" ] || {
            echo "warn: no $scope age key; skipping $scope export" >&2
            continue
        }
        for meta in "$scope_dir"/*/metadata.yaml; do
            [ -f "$meta" ] || continue
            id="$(basename "$(dirname "$meta")")"
            [ "$all" -eq 1 ] || projects_selected "$id" || continue
            local target="$repo/$scope/$id"
            mkdir -p "$target" || continue
            if ! projects_encrypt "$scope" "$meta" "$target/metadata.yaml" ||
                ! projects_encrypt "$scope" "$store/$scope/$id/env" "$target/env"; then
                echo "error: encryption failed for $scope/$id" >&2
                rc=1
                continue
            fi
            echo "exported $scope/$id"
        done
    done
    echo "==> Exported to $repo (remember to commit)."
    return $rc
}

projects_sync() {
    local store root rc scope scope_dir meta id name repo target sshkey
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
        sshkey="$(projects_sshkeyfile "$scope")"
        export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -i $sshkey"
        for meta in "$scope_dir"/*/metadata.yaml; do
            [ -f "$meta" ] || continue
            id="$(basename "$(dirname "$meta")")"
            projects_selected "$id" || continue
            name="$(jq -r '.name // empty' "$meta" 2>/dev/null)"
            repo="$(jq -r '.repo // empty' "$meta" 2>/dev/null)"
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

# Sidecar-hash-tracked env materialization from the decrypted working store.
# Never clobbers a locally edited .env; marks it stale with a redacted
# (key-name only) diff instead.
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

    if [ ! -f "$env_file" ]; then
        echo "warn: no env in store for $name; skipping" >&2
        return 0
    fi
    store_hash="$(sha256sum "$env_file" | awk '{print $1}')"

    if [ ! -f "$target" ]; then
        cp "$env_file" "$target"
        chmod 600 "$target"
        printf '%s\n' "$store_hash" >"$sidecar"
        echo "materialized $name/.env"
        return 0
    fi

    cur="$(sha256sum "$target" | awk '{print $1}')"
    last=""
    [ -f "$sidecar" ] && last="$(cat "$sidecar")"

    if [ "$cur" = "$store_hash" ]; then
        printf '%s\n' "$store_hash" >"$sidecar"
        return 0
    fi

    if [ "$cur" = "$last" ]; then
        cp "$env_file" "$target"
        chmod 600 "$target"
        printf '%s\n' "$store_hash" >"$sidecar"
        echo "updated $name/.env (store changed)"
        return 0
    fi

    echo "stale: $name/.env was edited locally; not clobbering" >&2
    projects_env_key_diff "$env_file" "$target" >&2 || true
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
    local store root scope scope_dir meta id name repo target env_file sidecar
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
        for meta in "$scope_dir"/*/metadata.yaml; do
            [ -f "$meta" ] || continue
            id="$(basename "$(dirname "$meta")")"
            name="$(jq -r '.name // empty' "$meta" 2>/dev/null)"
            repo="$(jq -r '.repo // empty' "$meta" 2>/dev/null)"
            target="$root/$name"
            env_status="no clone"
            if [ -d "$target/.git" ]; then
                env_file="$store/$scope/$id/env"
                sidecar="$HOME/.secrets/projects/$name.env.sha256"
                if [ ! -f "$target/.env" ]; then
                    env_status="missing"
                elif [ ! -f "$env_file" ]; then
                    env_status="no-store-env"
                else
                    cur="$(sha256sum "$target/.env" | awk '{print $1}')"
                    store_hash="$(sha256sum "$env_file" | awk '{print $1}')"
                    last=""
                    [ -f "$sidecar" ] && last="$(cat "$sidecar")"
                    if [ "$cur" = "$store_hash" ]; then
                        env_status="ok"
                    elif [ "$cur" = "$last" ]; then
                        env_status="store-changed"
                    else
                        env_status="STALE"
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
    cp "$src" "$target"
    chmod 600 "$target"
    sidecar="$HOME/.secrets/projects/$name.env.sha256"
    mkdir -p "$HOME/.secrets/projects" 2>/dev/null || true
    sha256sum "$src" | awk '{print $1}' >"$sidecar"
    echo "captured $name (scope $scope)"
    echo "  (run 'angst projects export' to push it to the encrypted repo store)"
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
    if [ ! -f "$env_file" ]; then
        echo "error: no env in store for $name" >&2
        return 1
    fi
    tmp="$(mktemp)" || return 1
    cp "$env_file" "$tmp"
    chmod 600 "$tmp"
    editor="${EDITOR:-vi}"
    if ! $editor "$tmp"; then
        echo "edit aborted; store unchanged" >&2
        rm -f "$tmp"
        return 1
    fi
    cp "$tmp" "$env_file"
    chmod 600 "$env_file"
    rm -f "$tmp"
    echo "updated $name env (scope $scope)"
    echo "  (run 'angst projects export' to push it to the encrypted repo store)"

    target="$(projects_root)/$name/.env"
    sidecar="$HOME/.secrets/projects/$name.env.sha256"
    if [ -f "$target" ] && [ -f "$sidecar" ]; then
        cur="$(sha256sum "$target" | awk '{print $1}')"
        last="$(cat "$sidecar")"
        if [ "$cur" = "$last" ]; then
            cp "$env_file" "$target"
            chmod 600 "$target"
            sha256sum "$target" | awk '{print $1}' >"$sidecar"
            echo "resynced $name/.env"
        fi
    fi
}

projects_rm() {
    local name="$1" res scope id store repo
    res="$(projects_resolve "$name" 2>/dev/null)" || {
        echo "error: unknown project '$name'" >&2
        return 1
    }
    read -r scope id <<<"$res"
    store="$(projects_store_root)"
    rm -rf "${store:?}/${scope:?}/${id:?}"
    repo="$(projects_repo_root)"
    rm -rf "${repo:?}/${scope:?}/${id:?}" 2>/dev/null || true
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
    import) projects_import "$@" ;;
    export) projects_export "$@" ;;
    rm) projects_rm "$@" ;;
    -h | --help | "") projects_usage ;;
    *)
        echo "unknown projects command: $cmd" >&2
        projects_usage >&2
        return 2
        ;;
    esac
}
