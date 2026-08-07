{
  pkgs,
  host,
  ...
}:

let
  inherit (host) password type;
  validSha512 = builtins.match ''\$6\$.+\$.+'' password;
in
pkgs.runCommand "check-password" { } (
  if type == "home-manager" then
    ''
      echo "--- Password check ---"
      echo "SKIP: home-manager host — password managed by host OS"
      touch $out
    ''
  else if password == "!" then
    ''
      echo "--- Password check ---"
      echo "SKIP: password not configured (CI or minimal host)"
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
