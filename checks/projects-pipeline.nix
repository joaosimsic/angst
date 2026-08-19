{
  pkgs,
  runtime,
}:

# Functional round-trip test of the `angst projects` pipeline, driving the
# real Go binary (runtime.goAngst), using throwaway age keys and synthetic
# data (no real secrets, no network):
#   export (encrypt) -> repo store is a valid, leak-free sops-age store
#   import (decrypt) -> byte-exact round trip of metadata + env
#   sync             -> .env materialized into a fake clone (0600, sidecar)
#   stale            -> locally-edited .env is not clobbered; status shows STALE

pkgs.runCommand "check-projects-pipeline"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.openssl
      pkgs.jq
      pkgs.git
      pkgs.sops
      pkgs.age
      pkgs.openssh
      runtime.goAngst
    ];
  }
  ''
    set -uo pipefail

    ok() { echo "PASS: $1"; }
    fail() {
      echo "FAIL: $1"
      failed=1
    }
    failed=0

    angst="${runtime.goAngst}/bin/angst"

    scratch="$(mktemp -d)"
    home="$scratch/home"
    store="$scratch/store"
    repo="$scratch/repo"
    root="$scratch/root"

    mkdir -p "$home/.config/sops/age" "$home/.ssh" "$home/.secrets/projects"
    age-keygen -o "$home/.config/sops/age/keys.txt"
    age-keygen -o "$home/.config/sops/age/work-keys.txt"

    export HOME="$home"
    export ANGST_PROJECTS_STORE="$store"
    export ANGST_PROJECTS_REPO="$repo"
    export ANGST_PROJECTS_ROOT="$root"
    export SOPS_AGE_KEY_FILE="$home/.config/sops/age/keys.txt"
    export SOPS_WORK_AGE_KEY_FILE="$home/.config/sops/age/work-keys.txt"

    echo "==> Seeding a synthetic working store (personal + work)..."

    personal_id="$(openssl rand -hex 8)"
    work_id="$(openssl rand -hex 8)"
    personal_name="pipeline-personal"
    work_name="pipeline-work"

    mkdir -p "$store/personal/$personal_id" "$store/work/$work_id"
    jq -n --arg name "$personal_name" --arg repo "git@example.invalid:pipeline/personal.git" \
      '{name: $name, repo: $repo}' > "$store/personal/$personal_id/metadata.yaml"
    printf 'PIPELINE_PERSONAL_KEY=secret-one\nPIPELINE_SHARED=yes\n' > "$store/personal/$personal_id/env"
    jq -n --arg name "$work_name" --arg repo "git@work.example.invalid:pipeline/work.git" \
      '{name: $name, repo: $repo}' > "$store/work/$work_id/metadata.yaml"
    printf 'PIPELINE_WORK_KEY=secret-two-ö\n' > "$store/work/$work_id/env"

    cp -a "$store" "$scratch/store.orig"

    echo "==> export --all (encrypt into the repo store)..."
    if ! "$angst" projects export --all; then
      fail "projects export --all failed"
    else
      ok "projects export --all"
    fi

    encrypted=0
    for f in $(find "$repo" -type f | sort); do
      encrypted=$((encrypted + 1))
      if ! grep -q 'BEGIN AGE ENCRYPTED FILE' "$f"; then
        fail "exported $f is not sops-age encrypted"
      elif grep -qE '"name"|"repo"|://|^[A-Za-z_][A-Za-z0-9_]*=' "$f"; then
        fail "exported $f leaks plaintext name/repo/secret content"
      fi
    done
    [ "$encrypted" -eq 4 ] && ok "exported 4 files (2 metadata + 2 env) all encrypted, no plaintext leaks"

    echo "==> Wipe working store, import --all, verify byte-exact round trip..."
    rm -rf "$store"
    if ! "$angst" projects import --all; then
      fail "projects import --all failed"
    else
      ok "projects import --all"
    fi
    (cd "$scratch/store.orig" && find . -type f | sort) | while read -r rel; do
      cmp "$scratch/store.orig/$rel" "$store/$rel" ||
        fail "round-trip mismatch: $rel"
    done
    ok "metadata + env byte-exact after import"

    echo "==> sync materializes .env into a fake clone..."
    mkdir -p "$root/$personal_name" "$root/$work_name"
    git init -q "$root/$personal_name"
    git init -q "$root/$work_name"
    if ! "$angst" projects sync; then
      fail "projects sync failed"
    fi
    for p in "$personal_name" "$work_name"; do
      if [ ! -f "$root/$p/.env" ]; then
        fail "no .env materialized for $p"
      elif [ "$(stat -c %a "$root/$p/.env")" != "600" ]; then
        fail "$p/.env permissions are not 0600"
      elif [ ! -f "$home/.secrets/projects/$p.env.sha256" ]; then
        fail "missing sidecar hash for $p/.env"
      else
        ok "$p/.env materialized (0600) with sidecar hash"
      fi
    done
    if grep -q 'PIPELINE_PERSONAL_KEY=secret-one' "$root/$personal_name/.env"; then
      ok "personal .env content intact"
    else
      fail "personal .env content changed"
    fi

    echo "==> Store change -> next sync updates .env..."
    printf 'PIPELINE_PERSONAL_KEY=secret-one\nPIPELINE_SHARED=yes\nPIPELINE_EXTRA=added\n' > "$store/personal/$personal_id/env"
    if ! "$angst" projects sync; then
      fail "projects sync after store change failed"
    fi
    if grep -q 'PIPELINE_EXTRA=added' "$root/$personal_name/.env"; then
      ok ".env updated from store change"
    else
      fail ".env not updated from store change"
    fi

    echo "==> Locally-edited .env is not clobbered; status flags STALE..."
    printf 'PIPELINE_PERSONAL_KEY=local-edit\n' > "$root/$personal_name/.env"
    sync_rc=0
    "$angst" projects sync || sync_rc=$?
    "$angst" projects status >"$scratch/status.txt" 2>&1 || true
    if [ "$sync_rc" -eq 1 ] && grep -q 'STALE' "$scratch/status.txt"; then
      ok "stale .env preserved (sync rc=$sync_rc, status flags STALE)"
    else
      fail "stale .env handling broken: sync rc=$sync_rc (expect 1)"
    fi
    if grep -q 'PIPELINE_PERSONAL_KEY=local-edit' "$root/$personal_name/.env"; then
      ok "edited .env untouched"
    else
      fail "edited .env was overwritten"
    fi

    if [ "$failed" -ne 0 ]; then
      echo "==> One or more projects-pipeline checks failed. Refusing to proceed."
      exit 1
    fi

    echo "==> All projects-pipeline checks passed."
    touch $out
  ''
