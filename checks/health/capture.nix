{
  pkgs,
  ...
}:
let
  homeSrc = ../../domains/capture/screenshot/home.nix;
  i3Src = ../../domains/wm/i3/home.nix;
  runtimeSrc = ../../runtime/capture-screenshot.nix;
in
{
  capture-screenshot =
    pkgs.runCommand "capture-screenshot-check"
      {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.gnugrep
        ];
      }
      ''
        set -euo pipefail

        home="${homeSrc}"
        i3="${i3Src}"
        runtime="${runtimeSrc}"

        echo "==> check: no defaults in home.nix"
        if grep -q 'default =' "$home"; then
          echo "capture/screenshot/home.nix must not contain 'default ='"
          grep -n 'default =' "$home" || true
          exit 1
        fi

        echo "==> check: single source picturesDir"
        cnt=$(grep -c '"\$HOME/Pictures"' "$home" || true)
        if [ "$cnt" -ne 1 ]; then
          echo "expected exactly 1 occurrence of \"\$HOME/Pictures\" in home.nix, got $cnt"
          grep -n 'Pictures' "$home" || true
          exit 1
        fi
        if grep -q 'Pictures/Screenshots' "$home"; then
          echo "must not contain Pictures/Screenshots"
          grep -n 'Pictures/Screenshots' "$home" || true
          exit 1
        fi
        if grep -q 'explicit' "$home"; then
          echo "must not contain explicit prefix"
          grep -n 'explicit' "$home" || true
          exit 1
        fi

        echo "==> check: runtime params are required (no ?)"
        for p in 'backend,' 'targetDir,' 'copyToClipboard,' 'saveToFile,' 'interactive,' 'name,'; do
          if ! grep -q "$p" "$runtime"; then
            echo "runtime missing required param $p"
            grep -n "$p" "$runtime" || true
            exit 1
          fi
        done
        if grep -E 'backend \?|targetDir \?|copyToClipboard \?|saveToFile \?|interactive \?' "$runtime" | grep -q .; then
          echo "runtime must not have ? defaults"
          grep -n -E 'backend \?|targetDir \?|copyToClipboard \?|saveToFile \?' "$runtime" || true
          exit 1
        fi

        echo "==> check: i3 bindings"
        if ! grep -Eq 'bindsym Print.*angst-screenshot-save fullscreen' "$i3"; then
          echo "missing i3 binding: Print -> save fullscreen"
          grep -n "bindsym" "$i3" || true
          exit 1
        fi
        if ! grep -Eq 'bindsym Shift\+Print.*angst-screenshot-copy region' "$i3"; then
          echo "missing i3 binding: Shift+Print -> copy region"
          grep -n "bindsym" "$i3" || true
          exit 1
        fi
        if ! grep -Eq 'bindsym \$mod\+Shift\+s.*angst-screenshot-copy region' "$i3"; then
          echo "missing i3 binding: mod+Shift+s -> copy region"
          grep -n "bindsym" "$i3" || true
          exit 1
        fi
        if ! grep -Eq 'bindsym \$mod\+Print.*angst-screenshot-save window' "$i3"; then
          echo "missing i3 binding: mod+Print -> save window"
          grep -n "bindsym" "$i3" || true
          exit 1
        fi

        echo "==> check: wrapper flags in home.nix source"
        if ! grep -q 'copyToClipboard = false' "$home"; then
          echo "save wrapper must have copyToClipboard = false"
          exit 1
        fi
        if ! grep -q 'saveToFile = true' "$home"; then
          echo "save wrapper must have saveToFile = true"
          exit 1
        fi
        if ! grep -q 'copyToClipboard = true' "$home"; then
          echo "copy wrapper must have copyToClipboard = true"
          exit 1
        fi
        if ! grep -q 'saveToFile = false' "$home"; then
          echo "copy wrapper must have saveToFile = false"
          exit 1
        fi

        # ensure picturesDir is used for both wrappers and domain assignment (single source)
        cntDir=$(grep -c 'picturesDir' "$home" || true)
        if [ "$cntDir" -lt 4 ]; then
          echo "expected picturesDir reused at least 4 times (let + 2 wrappers + assignment), got $cntDir"
          grep -n 'picturesDir' "$home" || true
          exit 1
        fi

        echo "capture screenshot checks passed"
        touch $out
      '';
}
