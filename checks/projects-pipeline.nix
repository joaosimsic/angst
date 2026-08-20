{
  pkgs,
  runtime,
}:

# Functional round-trip test of the `angst projects` pipeline, driving the
# real Go binary (runtime.goAngst), using throwaway age keys and synthetic
# data (no real secrets, no network):
#   vault encrypt --dir  -> age tarball (leak-free)
#   import               -> byte-exact working store (whole-scope tarball)
#   sync                 -> .env materialized into a fake clone (0600, sidecar)
#   stale               -> locally-edited .env is not clobbered; sync exits non-zero

pkgs.runCommand "check-projects-pipeline"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.openssl
      pkgs.git
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

    mkdir -p "$home/.config/sops/age" "$home/.ssh" "$home/.secrets/projects" "$repo"
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
    printf '{"name": "%s", "repo": "%s"}\n' "$personal_name" "git@example.invalid:pipeline/personal.git" \
      > "$store/personal/$personal_id/metadata.json"
    printf 'PIPELINE_PERSONAL_KEY=secret-one\nPIPELINE_SHARED=yes\n' > "$store/personal/$personal_id/.env"
    printf '{"name": "%s", "repo": "%s"}\n' "$work_name" "git@work.example.invalid:pipeline/work.git" \
      > "$store/work/$work_id/metadata.json"
    printf 'PIPELINE_WORK_KEY=secret-two-ö\n' > "$store/work/$work_id/.env"

    cp -a "$store" "$scratch/store.orig"

    echo "==> vault encrypt --dir (age tarball)..."
    for s in personal work; do
      if ! "$angst" vault encrypt "$store/$s" --dir --scope "$s"; then
        fail "vault encrypt --dir $s failed"
      elif [ ! -f "$store/$s.tar.age" ]; then
        fail "vault encrypt --dir did not create $s.tar.age"
      elif ! grep -q 'age-encryption.org/v1' "$store/$s.tar.age"; then
        fail "$s.tar.age is not age-encrypted"
      elif grep -qE '"name"|"repo"|://|^[A-Za-z_][A-Za-z0-9_]*=' "$store/$s.tar.age"; then
        fail "$s.tar.age leaks plaintext name/repo/secret content"
      else
        ok "$s encrypted to age tarball (no plaintext leak)"
      fi
      mv "$store/$s.tar.age" "$repo/$s.tar.age"
    done

    echo "==> Wipe working store, import, verify byte-exact round trip..."
    rm -rf "$store"
    if ! "$angst" projects import; then
      fail "projects import failed"
    else
      ok "projects import"
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
    printf 'PIPELINE_PERSONAL_KEY=secret-one\nPIPELINE_SHARED=yes\nPIPELINE_EXTRA=added\n' > "$store/personal/$personal_id/.env"
    if ! "$angst" projects sync; then
      fail "projects sync after store change failed"
    fi
    if grep -q 'PIPELINE_EXTRA=added' "$root/$personal_name/.env"; then
      ok ".env updated from store change"
    else
      fail ".env not updated from store change"
    fi

    echo "==> Locally-edited .env is not clobbered; sync exits non-zero..."
    printf 'PIPELINE_PERSONAL_KEY=local-edit\n' > "$root/$personal_name/.env"
    sync_rc=0
    "$angst" projects sync || sync_rc=$?
    if [ "$sync_rc" -ne 0 ] && grep -q 'PIPELINE_PERSONAL_KEY=local-edit' "$root/$personal_name/.env"; then
      ok "stale .env preserved (sync rc=$sync_rc, local edit untouched)"
    else
      fail "stale .env handling broken: sync rc=$sync_rc"
    fi

    if [ "$failed" -ne 0 ]; then
      echo "==> One or more projects-pipeline checks failed. Refusing to proceed."
      exit 1
    fi

    echo "==> All projects-pipeline checks passed."
    touch $out
  ''
