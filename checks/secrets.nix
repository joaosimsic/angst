{ pkgs }:

let
  repoRoot = ../.;

  secretsCheck =
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
      '';

  ftpCheck =
    pkgs.runCommand "check-ftp-encrypted"
      {
        nativeBuildInputs = [
          pkgs.findutils
          pkgs.gnugrep
        ];
      }
      ''
        set -euo pipefail
        cd ${repoRoot}

        files=$(find ./secrets/ftp -type f 2>/dev/null || true)
        if [ -z "$files" ]; then
          echo "No secrets/ftp files found; nothing to check."
          touch $out
          exit 0
        fi

        echo "==> Checking secrets/ftp files are age-encrypted (work key scope)..."
        failed=0
        for f in $files; do
          if ! grep -q 'BEGIN AGE ENCRYPTED FILE' "$f"; then
            echo "FAIL: $f is not age-encrypted (missing age envelope marker)"
            failed=1
          elif grep -qE '"host"|"user"|"pass"|"remote"|"path"|"config"|"type"|password' "$f"; then
            echo "FAIL: $f contains plaintext server/secret-like content"
            failed=1
          else
            echo "PASS: $f is age-encrypted"
          fi
        done

        if [ "$failed" -ne 0 ]; then
          echo "==> One or more secrets/ftp files are not properly encrypted. Refusing to proceed."
          exit 1
        fi

        echo "==> All secrets/ftp files are age-encrypted."
        touch $out
      '';

  projectsCheck =
    pkgs.runCommand "check-projects-encrypted"
      {
        nativeBuildInputs = [
          pkgs.findutils
          pkgs.gnugrep
        ];
      }
      ''
        set -euo pipefail
        cd ${repoRoot}

        files=$(find ./projects -type f \( -name 'metadata.yaml' -o -name 'env' \) 2>/dev/null || true)
        if [ -z "$files" ]; then
          echo "No projects store files found; nothing to check."
          touch $out
          exit 0
        fi

        echo "==> Checking projects store files are sops-encrypted (binary)..."
        failed=0
        for f in $files; do
          if ! grep -q 'BEGIN AGE ENCRYPTED FILE' "$f"; then
            echo "FAIL: $f is not sops-encrypted (missing age envelope marker)"
            failed=1
          elif grep -qE '"name"|"repo"|://|^[A-Za-z_][A-Za-z0-9_]*=' "$f"; then
            echo "FAIL: $f contains plaintext name/repo/URL/secret-like content"
            failed=1
          else
            echo "PASS: $f is sops-encrypted"
          fi
        done

        if [ "$failed" -ne 0 ]; then
          echo "==> One or more projects store files are not sops-encrypted. Refusing to proceed."
          exit 1
        fi

        echo "==> All projects store files are sops-encrypted."
        touch $out
      '';
in
{
  secrets = secretsCheck;
  projects = projectsCheck;
  ftp = ftpCheck;
}
