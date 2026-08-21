{
  pkgs,
  runtime,
}:

# Functional test of the `angst ftp` pipeline, using a throwaway work key and a
# synthetic rclone FTP config (no real secrets, no network):
#   encrypt sample JSON -> *.age (work-key scope)
#   decrypt via the real runtime.ftpSecretsHome wrapper -> ~/.secrets/ftp/*.conf
#   transform via the real `angst ftp transform` -> rclone INI (parseable offline)

let
  secretsHome = runtime.ftpSecretsHome {
    homeDirectory = "$CHK_FTP_HOME";
    configs = [
      {
        source = "$CHK_FTP_AGE";
        dest = ".secrets/ftp/ftp-server.conf";
      }
    ];
  };
in
pkgs.runCommand "check-ftp-pipeline"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.sops
      pkgs.age
      pkgs.rclone
      secretsHome
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
            work="$scratch/work"
            mkdir -p "$work"

            export HOME="$scratch"
            export CHK_FTP_HOME="$scratch/home"
            export CHK_FTP_AGE="$scratch/ftp-server.conf.age"
            export WORK_KEY="$scratch/work-keys.txt"
            export SOPS_WORK_AGE_KEY_FILE="$WORK_KEY"

            age-keygen -o "$WORK_KEY"

    echo "==> Encrypt a synthetic ftp rclone config to the work scope..."
        printf '%s\n' '{"remote": "angstci", "path": "/incoming", "config": {"type": "ftp", "host": "127.0.0.1", "user": "ci", "pass": "ci-secret-pass", "port": "2121"}}' >"$work/ftp.json"
        recipient="$(age-keygen -y "$WORK_KEY")"
        age -e -r "$recipient" -o "$CHK_FTP_AGE" "$work/ftp.json"

            if grep -q 'age-encryption.org/v1' "$CHK_FTP_AGE" && ! grep -q 'ci-secret-pass' "$CHK_FTP_AGE"; then
              ok "sample config encrypted (age envelope, no plaintext password)"
            else
              fail "sample config not properly encrypted"
            fi

            echo "==> Decrypt via the real runtime.ftpSecretsHome wrapper..."
            "${secretsHome}/bin/angst-ftp-secrets-home"

            conf="$CHK_FTP_HOME/.secrets/ftp/ftp-server.conf"
            if [ ! -f "$conf" ]; then
              fail "decrypted config not at $conf"
            elif [ "$(stat -c %a "$conf")" != "600" ]; then
              fail "decrypted config perms are $(stat -c %a "$conf"), expected 600"
            elif [ "$(stat -c %a "$CHK_FTP_HOME/.secrets/ftp")" != "700" ]; then
              fail ".secrets/ftp perms are $(stat -c %a "$CHK_FTP_HOME/.secrets/ftp"), expected 700"
            else
              ok "decrypted .conf present with 0600 file / 0700 dirs"
            fi
            if grep -q 'ci-secret-pass' "$conf"; then
              ok "decrypted config carries the secret (0600, as designed)"
            else
              fail "decrypted config missing the secret"
            fi

            echo "==> Render + validate the rclone INI via the real angst ftp transform..."
            "$angst" ftp transform --conf "$conf" --ini "$scratch/ftp.ini" > "$scratch/transform.out"
            FTP_REMOTE="$(sed -n 's/^remote=//p' "$scratch/transform.out")"
            FTP_PATH="$(sed -n 's/^path=//p' "$scratch/transform.out")"

            if [ "$FTP_REMOTE" != "angstci" ] || [ "$FTP_PATH" != "/incoming" ]; then
              fail "transform parsed wrong remote/path: $FTP_REMOTE / $FTP_PATH"
            fi
            if [ "$(stat -c %a "$scratch/ftp.ini")" != "600" ]; then
              fail "rendered ini perms are $(stat -c %a "$scratch/ftp.ini"), expected 600"
            fi
            if rclone listremotes --config "$scratch/ftp.ini" | grep -q '^angstci:$'; then
              ok "rclone parses the rendered INI ($(rclone listremotes --config "$scratch/ftp.ini" | tr -d '\n'))"
            else
              fail "rclone could not parse the rendered INI"
            fi
    if grep -q '^type = ftp$' "$scratch/ftp.ini" &&
          grep -q '^host = 127.0.0.1$' "$scratch/ftp.ini" &&
          grep -q '^pass = ci-secret-pass$' "$scratch/ftp.ini"; then
          ok "rendered INI has correct [section] + config keys"
        else
          fail "rendered INI missing expected [section]/keys"
        fi

            if [ "$failed" -ne 0 ]; then
              echo "==> One or more ftp-pipeline checks failed. Refusing to proceed."
              exit 1
            fi

            echo "==> All ftp-pipeline checks passed."
            touch $out
  ''
