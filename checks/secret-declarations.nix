{
  pkgs,
  lib,
  hostList,
}:

let
  repoRoot = ../.;

  passwordRows = lib.concatStringsSep "\n" (
    lib.concatMap (
      h: lib.optional (h.passwordSecret != null) "${h.hostname}\t${h.passwordSecret}"
    ) hostList
  );

  appRows = lib.concatStringsSep "\n" (
    lib.concatMap (h: map (ref: "${h.hostname}\t${ref}") (h.appSecrets or [ ])) hostList
  );

  hostRows = lib.concatStringsSep "\n" (
    lib.concatMap (
      h:
      map (
        ref:
        let
          parts = lib.splitString "/" ref;
        in
        "${h.hostname}\t${builtins.elemAt parts 0}\t${builtins.elemAt parts 1}"
      ) (h.hostSecrets or [ ])
    ) hostList
  );
in
pkgs.runCommand "check-secret-declarations"
  {
    nativeBuildInputs = [
      pkgs.findutils
      pkgs.gnugrep
    ];
  }
  ''
        set -uo pipefail
        cd ${repoRoot}

        failed=0
        ok() { echo "PASS: $1"; }
        warn() { echo "WARN: $1"; }
        fail() {
          echo "FAIL: $1"
          failed=1
        }

        check_age() {
          label=$1
          file=$2
          if [ ! -f "$file" ]; then
            warn "$label is declared but $file is missing"
          elif ! grep -q 'age-encryption.org/v1' "$file"; then
            fail "$label points at $file, which is not age-encrypted"
          else
            ok "$label -> $file"
          fi
        }

        echo "==> Checking declared password files..."
        while IFS=$'\t' read -r hostname name; do
          [ -z "$hostname" ] && continue
          check_age "$hostname password '$name'" "secrets/password/$name.age"
        done <<'PASSWORDS'
    ${passwordRows}
    PASSWORDS

        echo "==> Checking declared app secret files..."
        while IFS=$'\t' read -r hostname ref; do
          [ -z "$hostname" ] && continue
          check_age "$hostname app secret '$ref'" "secrets/apps/$ref.age"
        done <<'APPS'
    ${appRows}
    APPS

        echo "==> Checking declared host infrastructure secret files..."
        while IFS=$'\t' read -r hostname scope name; do
          [ -z "$hostname" ] && continue
          check_age "$hostname host secret '$scope/$name'" "secrets/$name/$hostname.age"
        done <<'HOSTS'
    ${hostRows}
    HOSTS

        echo "==> Checking host infrastructure secrets are not still under secrets/apps..."
        find secrets/apps -type f \( -name 'sunshine-credentials.age' -o -name 'tailscale-auth-key*.age' \) 2>/dev/null |
          while IFS= read -r f; do
            warn "host infrastructure secret still present at $f (remove after migration)"
          done

        if [ "$failed" -ne 0 ]; then
          echo "==> One or more secret declarations are invalid."
          exit 1
        fi

        echo "==> Secret declarations are valid; missing files are warnings."
        touch $out
  ''
