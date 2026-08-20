{
  pkgs,
  lib,
  hostList,
}:

# Cross-check host declarations against the encrypted repo store, without
# needing any decryption key:
#   - every host-declared `projects` id must resolve to an encrypted scope
#     tarball (projects/{personal,work}.tar.age). Per-id listing inside the
#     tarball requires a decryption key, so the per-id presence check now
#     happens at import/sync time (which warn + skip missing ids); here we
#     only confirm the relevant scope tarball is present and age-encrypted.
#   - every host-declared ftp mount must point at an existing, age-encrypted
#     secrets/ftp config, with a safe (relative, no `..`) mountPoint

let
  repoRoot = ../.;

  projRows = builtins.concatStringsSep "\n" (
    lib.concatMap (h: map (id: "${h.type}/${h.hostname}\t${id}") (h.projects or [ ])) hostList
  );

  ftpRows = builtins.concatStringsSep "\n" (
    lib.concatMap (
      h:
      map (
        m:
        "${h.type}/${h.hostname}\t${
          m.configFile or "secrets/ftp/ftp-server.conf.age"
        }\t${m.mountPoint or ""}"
      ) ((h.ftp or { }).mounts or [ ])
    ) hostList
  );
in
pkgs.runCommand "check-projects-ftp-declared"
  {
    nativeBuildInputs = [
      pkgs.findutils
      pkgs.gnugrep
    ];
  }
  ''
        set -uo pipefail
        cd ${repoRoot}

        ok() { echo "PASS: $1"; }
        fail() {
          echo "FAIL: $1"
          failed=1
        }
        failed=0

        echo "==> Checking host-declared projects resolve to an encrypted scope tarball..."
        count=0
        while IFS=$'\t' read -r hostname id; do
          count=$((count + 1))
          if { [ -f "projects/personal.tar.age" ] && grep -q 'age-encryption.org/v1' "projects/personal.tar.age"; } ||
            { [ -f "projects/work.tar.age" ] && grep -q 'age-encryption.org/v1' "projects/work.tar.age"; }; then
            ok "$hostname declares projects/$id (a scope tarball is present and encrypted)"
          else
            fail "$hostname declares projects/$id but no encrypted projects/{personal,work}.tar.age exists"
          fi
        done <<'EOF'
    ${projRows}
    EOF
        [ "$count" -gt 0 ] || echo "No host-declared projects; nothing to check."

        echo "==> Checking host-declared ftp mounts exist, are encrypted, and use a safe mountPoint..."
        count=0
        while IFS=$'\t' read -r hostname cfg mnt; do
          count=$((count + 1))
          case "$mnt" in
          "" | /* | *".."*)
            fail "$hostname ftp mountPoint '$mnt' is empty, absolute, or contains '..'"
            ;;
          esac
          if [ ! -f "$cfg" ]; then
            fail "$hostname ftp config $cfg not found in repo"
          elif ! grep -q 'BEGIN AGE ENCRYPTED FILE' "$cfg"; then
            fail "$hostname ftp config $cfg is not age-encrypted"
          else
            ok "$hostname ftp config $cfg (encrypted, mountPoint '$mnt')"
          fi
        done <<'EOF'
    ${ftpRows}
    EOF
        [ "$count" -gt 0 ] || echo "No host-declared ftp mounts; nothing to check."

        [ "$failed" -eq 0 ]
        touch $out
  ''
