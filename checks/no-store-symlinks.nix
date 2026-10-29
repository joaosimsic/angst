{ pkgs }:

let
  repoRoot = ../.;
in
pkgs.runCommand "check-no-store-symlinks"
  {
    nativeBuildInputs = [ pkgs.findutils ];
  }
  ''
        set -uo pipefail
        cd ${repoRoot}

        # No file in the repo tree may be a symlink into /nix/store, except an
        # explicit allowlist below. Background: home-manager writes its
        # deployed files through a manually dir-symlinked ~/.config/<app>
        # straight into the repo, replacing real sources with store symlinks.
        # Once committed, every rebuild flips the store hash and dirties the
        # whole tree (see domains/editor/nvim 2026-10 incident).
        #
        # Allowlist (all gitignored, reproduced outside the repo):
        #   ./result* — nix build outputs
        #   .../EnabledAdapters.lua + .../palette.lua — generated at
        #   activation/render time (domains/editor/nvim home.nix/render.nix)

        failed=0
        while IFS= read -r link; do
          case "$link" in
            ./result*) continue ;;
            ./domains/editor/nvim/config/lua/backend/shared/EnabledAdapters.lua) continue ;;
            ./domains/editor/nvim/config/lua/config/theme/palette.lua) continue ;;
          esac
          echo "FAIL: store symlink in repo tree: $link -> $(readlink "$link")"
          failed=1
        done < <(find . -path ./.git -prune -o -lname '/nix/store/*' -print | sort)

        if [ "$failed" -ne 0 ]; then
          echo "FAIL: untracked-or-tracked /nix/store symlinks found (see above)."
          echo "If home-manager wrote these, remove the ~/.config/<app> dir-symlink into the repo,"
          echo "restore real sources, and re-run the switch."
          exit 1
        fi

        echo "PASS: no unexpected /nix/store symlinks in repo tree."
        touch $out
  ''
