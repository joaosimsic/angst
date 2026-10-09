{
  pkgs,
  self,
  render,
}:

let
  outputs = map (o: { inherit (o) path text; }) render.renderProjectOutputs;
  expected = pkgs.writeText "expected-project-config.json" (builtins.toJSON outputs);
in
pkgs.runCommand "check-agent-project-config"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.jq
    ];
    expectedFile = expected;
    src = self;
  }
  ''
    set -euo pipefail

    failed=0
    n=$(jq 'length' "$expectedFile")
    i=0
    while [ "$i" -lt "$n" ]; do
      path=$(jq -r ".[$i].path" "$expectedFile")
      actual="$src/$path"
      want=$(mktemp)
      jq -j ".[$i].text" "$expectedFile" > "$want"
      if [ ! -f "$actual" ]; then
        echo "FAIL: $path missing in repo (run 'nix run .#render')"
        failed=1
      elif ! diff -u "$want" "$actual"; then
        echo "FAIL: $path out of sync with flake render output"
        failed=1
      else
        echo "PASS: $path in sync"
      fi
      rm -f "$want"
      i=$((i + 1))
    done

    if [ "$failed" -ne 0 ]; then
      echo "==> agent project config out of sync; run 'nix run .#render'"
      exit 1
    fi

    echo "==> agent project config in sync"
    touch "$out"
  ''
