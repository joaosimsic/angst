#!/usr/bin/env bash
# Shared runtime helpers, concatenated into every angst runtime script
# (angst CLI, ftp-mount, projects-sync) and the home-manager wrappers.
# Sourced as the FIRST fragment so later code can call these functions.

# Resolve the angst (flake) repo root at runtime. Priority:
#   1. $ANGST_REPO_ROOT          explicit override (e.g. systemctl --user edit)
#   2. git discovery             the current repo's top-level (real path)
#   3. $ANGST_REPO_FALLBACK      per-host configured path (set by the service)
#   4. $PWD                      last resort (mirrors the old `|| pwd`)
angst_repo_root() {
    if [ -n "${ANGST_REPO_ROOT:-}" ]; then
        printf '%s\n' "$ANGST_REPO_ROOT"
        return 0
    fi
    local root
    if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        printf '%s\n' "$root"
        return 0
    fi
    printf '%s\n' "${ANGST_REPO_FALLBACK:-$PWD}"
}

# Backwards-compatible alias: angst-projects.sh and the CLI call this name.
repo_root_default() {
    angst_repo_root
}
