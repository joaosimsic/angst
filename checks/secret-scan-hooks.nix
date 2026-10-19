{ pkgs }:

let
  repoRoot = ../.;
in
pkgs.runCommand "secret-scan-hooks"
  {
    nativeBuildInputs = [
      pkgs.gitleaks
      pkgs.git
      pkgs.gnugrep
      pkgs.coreutils
      pkgs.bash
    ];
  }
  ''
    set -euo pipefail
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    fail() { echo "FAIL: $1" >&2; exit 1; }
    pass() { echo "PASS: $1"; }

    export HOME="$work/home"
    mkdir -p "$HOME"

    mkdir -p "$work/hooks"
    cp ${repoRoot}/githooks/pre-commit ${repoRoot}/githooks/pre-push "$work/hooks/"
    for h in pre-commit pre-push; do
        sed -i "1s|^#!.*|#!${pkgs.bash}/bin/bash|" "$work/hooks/$h"
    done
    chmod +x "$work/hooks/"*

    repo="$work/repo"
    git init -q -b main "$repo"
    git -C "$repo" config user.email test@test
    git -C "$repo" config user.name test
    git -C "$repo" config core.hooksPath "$work/hooks"
    cp ${repoRoot}/.gitleaks.toml "$repo/"

    gh_p1='ghp_y'
    gh_p2='ar3TjQ95prkRPC7go9w7datuPIaXJ48VmHH'
    github_secret="$gh_p1$gh_p2"
    aws_p1='AKIA2'
    aws_p2='34567ABCDEFGHTW'
    aws_secret="$aws_p1$aws_p2"

    printf 'hello\n' > "$repo/ok.txt"
    git -C "$repo" add ok.txt
    git -C "$repo" commit -qm init || fail "pre-commit blocked a clean commit"
    pass "pre-commit allows clean commit"
    clean_sha=$(git -C "$repo" rev-parse HEAD)

    printf 'github_token = "%s"\n' "$github_secret" > "$repo/secret.txt"
    git -C "$repo" add secret.txt
    if git -C "$repo" commit -qm leak; then
        fail "pre-commit did NOT block a commit containing a secret"
    fi
    [ "$(git -C "$repo" log --oneline | wc -l)" -eq 1 ] || fail "secret commit was created despite pre-commit"
    pass "pre-commit blocks commit with secret"

    remote="$work/remote.git"
    git init -q --bare "$remote"
    git -C "$repo" remote add origin "$remote"
    git -C "$repo" push -q origin main || fail "pre-push blocked a clean push"
    pass "pre-push allows clean push"

    printf 'aws_access_key_id = "%s"\n' "$aws_secret" > "$repo/bad.txt"
    git -C "$repo" add bad.txt
    git -C "$repo" commit --no-verify -qm leak2
    if git -C "$repo" push origin main; then
        fail "pre-push did NOT block a push containing a secret"
    fi
    remote_head=$(git ls-remote "$remote" refs/heads/main)
    [ -n "$remote_head" ] || fail "remote has no main ref"
    case "$remote_head" in
      "$clean_sha"*) pass "pre-push blocks push with secret (remote unchanged)" ;;
      *) fail "remote was updated despite pre-push block: $remote_head" ;;
    esac

    echo "==> All secret-scan-hooks checks passed."
    touch $out
  ''
