{
  pkgs,
  cfg,
  ...
}:

let
  inherit (cfg) password;
  validSha512 = builtins.match ''\$6\$.+\$.+'' password;
in
pkgs.runCommand "check-password" { } (
  if password == "!" then
    ''
      echo "--- Password check ---"
      echo "SKIP: password managed via sops-nix (not in default.nix)"
      touch $out
    ''
  else if validSha512 == null then
    ''echo "FAIL: password is not a valid SHA-512 hash (\$6\$... format expected)"; exit 1''
  else
    ''
      echo "--- Password check ---"
      echo "PASS: valid SHA-512 password hash"
      touch $out
    ''
)
