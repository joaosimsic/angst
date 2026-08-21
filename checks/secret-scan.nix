{ pkgs }:

let
  repoRoot = ../.;
in
pkgs.runCommand "secret-scan"
  {
    nativeBuildInputs = [
      pkgs.gitleaks
      pkgs.trufflehog
      pkgs.git
      pkgs.openssh
      pkgs.gnugrep
      pkgs.findutils
      pkgs.coreutils
    ];
  }
  ''
        set -euo pipefail
        work=$(mktemp -d)
        trap 'rm -rf "$work"' EXIT

        fail() { echo "FAIL: $1" >&2; exit 1; }
        pass() { echo "PASS: $1"; }

        mkdir -p "$work/leaks/github" "$work/leaks/aws" "$work/leaks/slack" "$work/leaks/private-key" "$work/leaks/plain-secrets" "$work/leaks/projects-secret/projects/personal/3f9a1c2b4d7e09a2"

        gh_p1='ghp_y'
        gh_p2='ar3TjQ95prkRPC7go9w7datuPIaXJ48VmHH'
        github_secret="$gh_p1$gh_p2"
        printf 'github_token = "%s"\n' "$github_secret" > "$work/leaks/github/github.txt"

        aws_p1='AKIA2'
        aws_p2='34567ABCDEFGHTW'
        aws_secret="$aws_p1$aws_p2"
        printf 'aws_access_key_id = "%s"\n' "$aws_secret" > "$work/leaks/aws/aws.txt"

        slack_p1='https://hooks.slack.com/services/T00000000/B00000000/Zx9Qw2ErTy8Ui'
        slack_p2='OpAsDfGhJkLmNvBcVbNmAq'
        slack_secret="$slack_p1$slack_p2"
        printf 'webhook = "%s"\n' "$slack_secret" > "$work/leaks/slack/slack.txt"

        ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -f "$work/leaks/private-key/key" -N "" -C "test"
        mv "$work/leaks/private-key/key" "$work/leaks/private-key/key.txt"

        printf 'masterPassword: "supersecret-password"\n' > "$work/leaks/plain-secrets/secrets.yaml"

        sk_p1='sk-test-12345678'
        sk_p2='90abcdefghij'
        printf 'API_KEY = "%s%s"\n' "$sk_p1$sk_p2" > "$work/leaks/projects-secret/projects/personal/3f9a1c2b4d7e09a2/env"

        mkdir -p "$work/age"
        cat > "$work/age/opencode-go-key.age" <<'EOF'
age-encryption.org/v1
-> X25519 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-----BEGIN AGE ENCRYPTED FILE-----
YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSB2Qkd1T2R6OEU2VSttSEZu
d2QrZEhQc1lGVUxTZVY5MkJxTVlac0tSdERZCnJrZVc0aTRjWHdRcDVzcTBWa1N1
-----END AGE ENCRYPTED FILE-----
EOF

        mkdir -p "$work/report"
        expect_gitleaks_leak() {
            local dir=$1 ruleid=$2 cfg=''${3:-}
            local report=$work/report/$(basename "$dir").json
            if [ -z "$cfg" ]; then
                gitleaks detect --no-git --source "$dir" --report-path "$report" --report-format json --no-banner --redact >/dev/null 2>&1 \
                    && fail "gitleaks: expected rule '$ruleid' in $(basename "$dir") but scan exited 0"
            else
                gitleaks detect --no-git --source "$dir" --config "$cfg" --report-path "$report" --report-format json --no-banner --redact >/dev/null 2>&1 \
                    && fail "gitleaks: expected rule '$ruleid' in $(basename "$dir") but scan exited 0"
            fi
            grep -q "$ruleid" "$report" \
                || fail "gitleaks: rule '$ruleid' not reported for $(basename "$dir")"
            pass "gitleaks detects $ruleid in $(basename "$dir")"
        }

        expect_gitleaks_leak "$work/leaks/github" "github-pat"
        expect_gitleaks_leak "$work/leaks/aws" "aws-access-token"
        expect_gitleaks_leak "$work/leaks/slack" "slack-webhook-url"
        expect_gitleaks_leak "$work/leaks/private-key" "private-key"
        expect_gitleaks_leak "$work/leaks/plain-secrets" "angst-plaintext-secret-value" ${repoRoot}/.gitleaks.toml
        expect_gitleaks_leak "$work/leaks/projects-secret" "angst-projects-plaintext-secret-value" ${repoRoot}/.gitleaks.toml

        gitleaks detect --no-git --source "$work/age" --config ${repoRoot}/.gitleaks.toml --no-banner --redact >/dev/null 2>&1 \
            || fail "gitleaks: flagged the age-encrypted fixture"
        pass "gitleaks allows age-encrypted fixture"

        gitleaks detect --no-git --source ${repoRoot} --config ${repoRoot}/.gitleaks.toml --no-banner --redact >/dev/null 2>&1 \
            || fail "gitleaks: found leaks or false positives in the repository"
        pass "gitleaks is clean on the repository"

        set +e
        trufflehog filesystem "$work/leaks/github" --results=verified,unverified,unknown --no-verification --fail >/dev/null 2>&1
        rc=$?
        set -e
        [ "$rc" -eq 183 ] || fail "trufflehog: expected detection in github fixture, got exit $rc"
        pass "trufflehog detects secrets in github fixture"

        trufflehog filesystem "$work/age" --results=verified,unverified,unknown --no-verification >/dev/null 2>&1 \
            || fail "trufflehog: flagged the age-encrypted fixture"
        pass "trufflehog allows age-encrypted fixture"

        echo "==> All secret-scan checks passed."
        touch $out
  ''
