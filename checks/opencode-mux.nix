{ pkgs }:

let
  fakeOpencode = pkgs.writeShellScriptBin "opencode" ''
    printf 'args=%s\n' "$*"
    printf 'cwd=%s\n' "$PWD"
    printf 'key=%s\n' "''${OPENCODE_GO_API_KEY:+set}"
    printf 'password=%s\n' "''${OPENCODE_SERVER_PASSWORD:+set}"
  '';

  mux = import ../domains/agents/opencode/mux.nix {
    inherit pkgs;
    opencodePackage = fakeOpencode;
    config = {
      home.homeDirectory = "$TMPDIR/home";
      xdg.stateHome = "$TMPDIR/state";
    };
    portStart = 4210;
    portEnd = 4219;
    idleTimeout = 0;
  };
in
pkgs.runCommand "check-opencode-mux"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
  }
  ''
    export XDG_RUNTIME_DIR="$TMPDIR/run"
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME/.secrets" "$TMPDIR/run" "$TMPDIR/proj"
    printf 'dummy-key\n' > "$HOME/.secrets/opencode-go-key"
    chmod 600 "$HOME/.secrets/opencode-go-key"

    ${mux}/bin/opencode-mux status | grep -qF 'no servers'
    ${mux}/bin/opencode-mux reap

    if ${mux}/bin/opencode-mux server > "$TMPDIR/missing.out" 2> "$TMPDIR/missing.err"; then
      echo 'opencode-mux server accepted missing environment' >&2
      exit 1
    fi
    grep -qF 'OPENCODE_MUX_DIR and OPENCODE_MUX_PORT are required' "$TMPDIR/missing.err"

    OPENCODE_MUX_DIR="$TMPDIR/proj" OPENCODE_MUX_PORT=4210 \
      ${mux}/bin/opencode-mux server > "$TMPDIR/server.out" 2> "$TMPDIR/server.err"
    test ! -s "$TMPDIR/server.err"
    grep -qF 'args=serve --hostname 127.0.0.1 --port 4210' "$TMPDIR/server.out"
    grep -qF "cwd=$TMPDIR/proj" "$TMPDIR/server.out"
    grep -qF 'key=set' "$TMPDIR/server.out"
    grep -qF 'password=set' "$TMPDIR/server.out"
    test "$(stat -c %a "$TMPDIR/state/opencode/mux/password")" = "600"

    if OPENCODE_MUX_DIR="$TMPDIR/proj" OPENCODE_MUX_PORT=abc \
      ${mux}/bin/opencode-mux server > "$TMPDIR/badport.out" 2> "$TMPDIR/badport.err"; then
      echo 'opencode-mux server accepted an invalid port' >&2
      exit 1
    fi
    grep -qF 'invalid port' "$TMPDIR/badport.err"

    touch $out
  ''
