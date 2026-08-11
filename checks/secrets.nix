{ pkgs }:

let
  repoRoot = ../.;
in
pkgs.runCommand "check-secrets-encrypted"
  {
    nativeBuildInputs = [
      pkgs.findutils
      pkgs.gnugrep
    ];
  }
  ''
    set -euo pipefail
    cd ${repoRoot}

    files=$(find . -type f \( -name 'secrets.yaml' -o -name 'secrets.yml' \))
    if [ -z "$files" ]; then
      echo "No secrets.yaml files found; nothing to check."
      touch $out
      exit 0
    fi

    echo "==> Checking tracked secrets files are sops-encrypted..."
    failed=0
    for f in $files; do
      if ! grep -q '^sops:' "$f" || ! grep -q 'ENC\[AES256_GCM' "$f"; then
        echo "FAIL: $f is not sops-encrypted (missing 'sops:' block or ENC[AES256_GCM values)"
        failed=1
      else
        echo "PASS: $f is sops-encrypted"
      fi
    done

    if [ "$failed" -ne 0 ]; then
      echo "==> One or more secrets files are not sops-encrypted. Refusing to proceed."
      exit 1
    fi

    echo "==> All secrets files are sops-encrypted."
    touch $out
  ''
