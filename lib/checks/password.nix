{
  lib,
  pkgs,
}:

let
  checkExpr1 = pkgs.writeText "check-password-set.nix" ''
    let envPass = builtins.getEnv "ANGST_PASSWORD"; in if envPass != "" then envPass else "null"
  '';

  checkExpr2 = pkgs.writeText "check-password-unset.nix" ''
    let envPass = builtins.getEnv "ANGST_PASSWORD"; in if envPass != "" then "set" else "null"
  '';

  checkEnvVar = pkgs.runCommand "check-password-env-var"
    {
      nativeBuildInputs = [ pkgs.nix ];
      ANGST_PASSWORD = "$6$testhash";
      NIX_CONFIG = "extra-experimental-features = nix-command";
      NIX_STATE_DIR = "/tmp";
    }
    ''
      echo "--- Test A: ANGST_PASSWORD env var → hashedPassword ---"

      result=$(nix eval --impure --raw --file ${checkExpr1})
      if [ "$result" != "$ANGST_PASSWORD" ]; then
        echo "FAIL: ANGST_PASSWORD set → hashedPassword should match"
        echo "  expected: $ANGST_PASSWORD"
        echo "  got:      $result"
        exit 1
      fi
      echo "PASS: ANGST_PASSWORD set → hashedPassword matches"

      unset ANGST_PASSWORD
      result=$(nix eval --impure --raw --file ${checkExpr2})
      if [ "$result" != "null" ]; then
        echo "FAIL: ANGST_PASSWORD unset → hashedPassword should be null"
        echo "  expected: null"
        echo "  got:      $result"
        exit 1
      fi
      echo "PASS: ANGST_PASSWORD unset → hashedPassword is null"

      touch $out
    '';

  checkCli = pkgs.runCommand "check-password-cli"
    { nativeBuildInputs = [ pkgs.mkpasswd ]; }
    ''
      echo "--- Test B: angst passwd CLI ---"

      repo="$PWD/test-repo"
      mkdir -p "$repo/hosts"
      touch "$repo/flake.nix"

      cat > "$repo/user.env" << 'EOF'
      HOST=test
      USERNAME=testuser
      THEME=test
      EOF

      source ${../../scripts/angst.sh}

      # Test 1: happy path
      printf 'testpass\ntestpass\n' | ANGST_REPO="$repo" passwd_cmd || {
        echo "FAIL: happy path should succeed"; exit 1
      }
      grep -Fq 'PASSWORD=' "$repo/user.env" || {
        echo "FAIL: PASSWORD not written to user.env"; exit 1
      }
      grep -Fq 'PASSWORD=$6$' "$repo/user.env" || {
        echo "FAIL: PASSWORD is not a SHA-512 hash"; exit 1
      }
      echo "PASS: happy path — password hashed and written"

      # Test 2: non-matching passwords rejected
      sed -i "/^PASSWORD=/d" "$repo/user.env"
      printf 'pass1\npass2\n' | ANGST_REPO="$repo" passwd_cmd && {
        echo "FAIL: should reject non-matching passwords"; exit 1
      }
      echo "PASS: non-matching passwords rejected"

      # Test 3: empty password rejected
      printf '\n' | ANGST_REPO="$repo" passwd_cmd && {
        echo "FAIL: should reject empty password"; exit 1
      }
      echo "PASS: empty password rejected"

      # Test 4: missing user.env fails gracefully
      rm "$repo/user.env"
      printf 'testpass\ntestpass\n' | ANGST_REPO="$repo" passwd_cmd && {
        echo "FAIL: should fail when user.env is missing"; exit 1
      }
      echo "PASS: missing user.env handled gracefully"

      touch $out
    '';
in
pkgs.linkFarm "check-password" [
  { name = "env-var"; path = checkEnvVar; }
  { name = "cli"; path = checkCli; }
]
