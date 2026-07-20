{
  lib,
  pkgs,
  cfg,
}:

let
  password = cfg.password;
  validSha512 = builtins.match ''\$6\$.+\$.+'' password;
in
pkgs.runCommand "check-password" { } (
  if password == "!" then
    ''
      echo "--- Password check ---"
      echo "SKIP: no local/config.nix (default password — not an error)"
      touch $out
    ''
  else if validSha512 == null then
    ''echo "FAIL: password in local/config.nix is not a valid SHA-512 hash (\$6\$... format expected)"; exit 1''
  else
    ''
      echo "--- Password check ---"
      echo "PASS: local/config.nix contains a valid SHA-512 password hash"
      touch $out
    ''
)
