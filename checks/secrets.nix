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

        files=$(find ./secrets/master -type f -name '*.age' 2>/dev/null || true)
        if [ -z "$files" ]; then
          echo "No secrets/master/*.age files found; nothing to check."
          touch $out
          exit 0
        fi

        echo "==> Checking tracked master-password age files are age-encrypted..."
        failed=0
        for f in $files; do
          if ! grep -q 'age-encryption.org/v1' "$f"; then
            echo "FAIL: $f is not age-encrypted (missing age-encryption.org/v1 envelope)"
            failed=1
          elif grep -qE '(password|passphrase|token|secret|api[_-]?key|access[_-]?key|client[_-]?secret)\s*[:=]' "$f"; then
            echo "FAIL: $f contains plaintext secret-like content"
            failed=1
          else
            echo "PASS: $f is age-encrypted"
          fi
        done

        if [ "$failed" -ne 0 ]; then
          echo "==> One or more master-password files are not properly encrypted. Refusing to proceed."
          exit 1
        fi

        echo "==> All master-password files are age-encrypted."
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
          if ! grep -q 'age-encryption.org/v1' "$f"; then
            echo "FAIL: $f is not age-encrypted (missing age-encryption.org/v1 envelope)"
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

        files=$(find ./projects -type f -name '*.tar.age' 2>/dev/null || true)
        if [ -z "$files" ]; then
          echo "No projects tarballs found; nothing to check."
          touch $out
          exit 0
        fi

        echo "==> Checking projects tarballs are age-encrypted..."
        failed=0
        for f in $files; do
          if ! grep -q 'age-encryption.org/v1' "$f"; then
            echo "FAIL: $f is not age-encrypted (missing age envelope marker)"
            failed=1
          else
            echo "PASS: $f is age-encrypted"
          fi
        done

        if [ "$failed" -ne 0 ]; then
          echo "==> One or more projects tarballs are not age-encrypted. Refusing to proceed."
          exit 1
        fi

        echo "==> All projects tarballs are age-encrypted."
        touch $out
      '';
  sshKeysCheck =
    pkgs.runCommand "check-ssh-keys-encrypted"
      {
        nativeBuildInputs = [
          pkgs.findutils
          pkgs.gnugrep
          pkgs.openssh
        ];
      }
      ''
        set -euo pipefail
        cd ${repoRoot}

        files=$(find ./secrets/ssh -type f -name '*.age' 2>/dev/null || true)
        if [ -z "$files" ]; then
          echo "No secrets/ssh/*.age files found; nothing to check."
          touch $out
          exit 0
        fi

        echo "==> Checking tracked SSH keys are age-encrypted and match their .pub..."
        failed=0
        for f in $files; do
          base="''${f%.age}"
          pub="$base.pub"
          if ! grep -q -- 'age-encryption.org/v1' "$f"; then
            echo "FAIL: $f is not age-encrypted (missing age-encryption.org/v1 envelope)"
            failed=1
          elif grep -qF -- '-----BEGIN OPENSSH PRIVATE KEY-----' "$f"; then
            echo "FAIL: $f contains plaintext OpenSSH private key material"
            failed=1
          elif [ ! -f "$pub" ]; then
            echo "FAIL: $f has no matching $pub"
            failed=1
          elif ! ssh-keygen -lf "$pub" >/dev/null 2>&1; then
            echo "FAIL: $pub is not a valid OpenSSH public key"
            failed=1
          else
            echo "PASS: $f is age-encrypted, envelope intact, $pub valid"
          fi
        done

        if [ "$failed" -ne 0 ]; then
          echo "==> One or more SSH key files are not properly encrypted/valid. Refusing to proceed."
          echo "    The .pub <-> .age correspondence is cross-checked with:"
          echo "    angst ssh-key verify --scope <personal|work>"
          exit 1
        fi

        echo "==> All SSH key files are age-encrypted with valid public keys."
        touch $out
      '';
in
{
  secrets = secretsCheck;
  projects = projectsCheck;
  sshKeys = sshKeysCheck;
  ftp = ftpCheck;
}
