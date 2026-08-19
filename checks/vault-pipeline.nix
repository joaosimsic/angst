{
  pkgs,
  runtime,
}:

# Functional round-trip test of `angst vault`, driving the real Go binary
# (runtime.goAngst) with throwaway age keys and synthetic data (no real
# secrets, no network):
#   encrypt (file)   -> .age is valid age ciphertext, source preserved
#   decrypt (file)   -> byte-exact round trip
#   encrypt (dir)    -> all files encrypted, .age skipped, source preserved
#   decrypt (dir)    -> byte-exact restoration
#   encrypt --dir    -> tarball age file, original removed
#   decrypt --dir    -> directory restored, byte-exact
#   status           -> correct encrypted/plaintext reporting
#   --force/--delete -> overwrite existing + source removal
#   --scope work     -> isolated key scope (cross-scope decrypt rejected)
#   errors           -> missing path / --dir on file / --dir on non-tar.age / unknown cmd

pkgs.runCommand "check-vault-pipeline"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.age
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
    mkdir -p "$home/.config/sops/age"
    age-keygen -o "$home/.config/sops/age/keys.txt"
    age-keygen -o "$home/.config/sops/age/work-keys.txt"

    export HOME="$home"
    export SOPS_AGE_KEY_FILE="$home/.config/sops/age/keys.txt"
    export SOPS_WORK_AGE_KEY_FILE="$home/.config/sops/age/work-keys.txt"

    echo "==> File encrypt/decrypt round trip..."
    fdir="$scratch/file"
    mkdir -p "$fdir"
    printf 'token: super-secret\n' > "$fdir/secret.yaml"
    if ! "$angst" vault encrypt "$fdir/secret.yaml"; then
      fail "vault encrypt (file) failed"
    elif [ ! -f "$fdir/secret.yaml.age" ]; then
      fail "vault encrypt (file) did not create .age"
    elif [ ! -f "$fdir/secret.yaml" ]; then
      fail "vault encrypt (file) removed source without --delete"
    else
      ok "vault encrypt (file) created .age, kept source"
    fi

    if ! grep -q 'age-encryption.org/v1' "$fdir/secret.yaml.age"; then
      fail "encrypted .age is not valid age ciphertext"
    elif grep -q 'super-secret' "$fdir/secret.yaml.age"; then
      fail "encrypted .age leaks plaintext source content"
    else
      ok "encrypted .age is age ciphertext with no plaintext leak"
    fi

    if ! "$angst" vault decrypt "$fdir/secret.yaml.age"; then
      fail "vault decrypt (file) failed"
    elif [ "$(cat "$fdir/secret.yaml")" != "token: super-secret" ]; then
      fail "vault decrypt (file) round trip mismatch"
    elif [ "$(stat -c %a "$fdir/secret.yaml")" != "600" ]; then
      fail "vault decrypt (file) did not set 0600 perms"
    else
      ok "vault decrypt (file) byte-exact round trip (0600)"
    fi

    echo "==> Directory (file mode) encrypt/decrypt round trip..."
    ddir="$scratch/dir"
    mkdir -p "$ddir/sub"
    printf 'alpha\n' > "$ddir/a.txt"
    printf 'beta\n' > "$ddir/sub/b.txt"
    if ! "$angst" vault encrypt "$ddir"; then
      fail "vault encrypt (dir) failed"
    elif [ ! -f "$ddir/a.txt.age" ] || [ ! -f "$ddir/sub/b.txt.age" ]; then
      fail "vault encrypt (dir) did not encrypt nested files"
    else
      ok "vault encrypt (dir) encrypted all files recursively"
    fi

    if ! "$angst" vault decrypt "$ddir"; then
      fail "vault decrypt (dir) failed"
    elif [ "$(cat "$ddir/a.txt")" != "alpha" ] || [ "$(cat "$ddir/sub/b.txt")" != "beta" ]; then
      fail "vault decrypt (dir) round trip mismatch"
    else
      ok "vault decrypt (dir) byte-exact round trip"
    fi

    echo "==> Directory mode (tar + age) round trip..."
    tdir="$scratch/td"
    mkdir -p "$tdir/sub"
    printf 'one\n' > "$tdir/x.txt"
    printf 'two\n' > "$tdir/sub/y.txt"
    if ! "$angst" vault encrypt "$tdir" --dir; then
      fail "vault encrypt --dir failed"
    elif [ ! -f "$tdir.tar.age" ]; then
      fail "vault encrypt --dir did not create .tar.age"
    elif [ -d "$tdir" ]; then
      fail "vault encrypt --dir did not remove original directory"
    else
      ok "vault encrypt --dir created .tar.age and removed source dir"
    fi

    if ! "$angst" vault decrypt "$tdir.tar.age" --dir; then
      fail "vault decrypt --dir failed"
    elif [ "$(cat "$tdir/x.txt")" != "one" ] || [ "$(cat "$tdir/sub/y.txt")" != "two" ]; then
      fail "vault decrypt --dir round trip mismatch"
    else
      ok "vault decrypt --dir restored directory byte-exactly"
    fi

    echo "==> status reporting..."
    # Encrypt a fresh file so both the .age and plaintext forms exist for status.
    sdir="$scratch/status"
    mkdir -p "$sdir"
    printf 'payload\n' > "$sdir/s.txt"
    "$angst" vault encrypt "$sdir/s.txt"

    st_out="$("$angst" vault status "$sdir" 2>&1)"
    if ! echo "$st_out" | grep -q 'encrypted: 1, plaintext: 1'; then
      fail "vault status (dir) incorrect: $st_out"
    else
      ok "vault status (dir) reports 1 encrypted / 1 plaintext"
    fi

    st_file="$("$angst" vault status "$sdir/s.txt" 2>&1)"
    if ! echo "$st_file" | grep -q 'plaintext'; then
      fail "vault status (file) incorrect: $st_file"
    else
      ok "vault status (file) reports plaintext"
    fi

    st_age="$("$angst" vault status "$sdir/s.txt.age" 2>&1)"
    if ! echo "$st_age" | grep -q 'encrypted'; then
      fail "vault status (.age) incorrect: $st_age"
    else
      ok "vault status (.age) reports encrypted"
    fi

    echo "==> --force and --delete flags..."
    fflag="$scratch/ff"
    mkdir -p "$fflag"
    printf 'orig\n' > "$fflag/f.txt"
    "$angst" vault encrypt "$fflag/f.txt"
    printf 'TAMPER' > "$fflag/f.txt.age"
    if "$angst" vault encrypt "$fflag/f.txt"; then
      if [ "$(cat "$fflag/f.txt.age")" != "TAMPER" ]; then
        fail "vault encrypt without --force overwrote existing .age"
      else
        ok "vault encrypt without --force skipped existing .age"
      fi
    else
      fail "vault encrypt (skip) returned non-zero"
    fi

    "$angst" vault encrypt "$fflag/f.txt" --force
    if ! "$angst" vault decrypt "$fflag/f.txt.age"; then
      fail "vault decrypt after --force failed"
    elif [ "$(cat "$fflag/f.txt")" != "orig" ]; then
      fail "vault --force did not re-encrypt source"
    else
      ok "vault --force re-encrypted existing .age"
    fi

    printf 'del\n' > "$fflag/d.txt"
    if ! "$angst" vault encrypt "$fflag/d.txt" --delete; then
      fail "vault encrypt --delete failed"
    elif [ -f "$fflag/d.txt" ]; then
      fail "vault encrypt --delete did not remove source"
    elif [ ! -f "$fflag/d.txt.age" ]; then
      fail "vault encrypt --delete did not create .age"
    else
      ok "vault encrypt --delete removed source, kept .age"
    fi

    echo "==> --scope work isolation..."
    wdir="$scratch/work"
    mkdir -p "$wdir"
    printf 'work-secret\n' > "$wdir/w.txt"
    if ! "$angst" vault encrypt "$wdir/w.txt" --scope work; then
      fail "vault encrypt --scope work failed"
    elif ! "$angst" vault decrypt "$wdir/w.txt.age" --scope work; then
      fail "vault decrypt --scope work failed"
    elif [ "$(cat "$wdir/w.txt")" != "work-secret" ]; then
      fail "vault --scope work round trip mismatch"
    else
      ok "vault --scope work round trips"
    fi

    # Default (personal) encrypt must NOT decrypt under work scope.
    printf 'personal-secret\n' > "$wdir/m.txt"
    "$angst" vault encrypt "$wdir/m.txt"
    if "$angst" vault decrypt "$wdir/m.txt.age" --scope work 2>/dev/null; then
      fail "vault decrypt with wrong scope should be rejected"
    else
      ok "vault cross-scope decrypt rejected"
    fi

    echo "==> Error handling..."
    if "$angst" vault encrypt "$scratch/nonexistent.txt" 2>/dev/null; then
      fail "vault encrypt on missing path should error"
    else
      ok "vault encrypt missing path errors"
    fi
    if "$angst" vault decrypt "$scratch/nonexistent.age" 2>/dev/null; then
      fail "vault decrypt on missing path should error"
    else
      ok "vault decrypt missing path errors"
    fi
    if "$angst" vault encrypt "$fflag/f.txt" --dir 2>/dev/null; then
      fail "vault encrypt --dir on a file should error"
    else
      ok "vault encrypt --dir on file errors"
    fi
    if "$angst" vault decrypt "$fflag/f.txt" --dir 2>/dev/null; then
      fail "vault decrypt --dir on non-tar.age should error"
    else
      ok "vault decrypt --dir on non-tar.age errors"
    fi
    if "$angst" vault frobnicate x 2>/dev/null; then
      fail "vault unknown command should error"
    else
      ok "vault unknown command errors"
    fi

    if [ "$failed" -ne 0 ]; then
      echo "==> One or more vault-pipeline checks failed. Refusing to proceed."
      exit 1
    fi

    echo "==> All vault-pipeline checks passed."
    touch "$out"
  ''
