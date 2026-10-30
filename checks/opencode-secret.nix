{
  pkgs,
  opencodeConfig,
}:

let
  fakeOpencode = pkgs.writeShellScriptBin "opencode" ''
    if [ -n "''${OPENCODE_GO_API_KEY:-}" ]; then
      printf 'key=%s\n' "$OPENCODE_GO_API_KEY"
    else
      printf 'key=<unset>\n'
    fi
    printf 'args=%s\n' "$*"
  '';

  fakeNotifySend = pkgs.writeShellScriptBin "notify-send" ''
    printf '%s\n' "$*" >> "$NOTIFY_LOG"
  '';

  fakeMux = pkgs.writeShellScriptBin "opencode-mux" ''
    printf 'mux-args=%s\n' "$*"
  '';

  wrapper = import ../domains/agents/opencode/wrapper.nix {
    inherit pkgs;
    opencodePackage = fakeOpencode;
    notifySend = fakeNotifySend;
  };

  wrapperMux = import ../domains/agents/opencode/wrapper.nix {
    inherit pkgs;
    opencodePackage = fakeOpencode;
    muxPackage = fakeMux;
    muxEnabled = true;
    notifySend = fakeNotifySend;
  };

  expectedConfig = pkgs.writeText "opencode-config.jsonc" opencodeConfig;
in
pkgs.runCommand "check-opencode-secret"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    export NOTIFY_LOG="$TMPDIR/notify.log"
    mkdir -p "$HOME/.secrets"
    : > "$NOTIFY_LOG"

    ${wrapper}/bin/opencode alpha > "$TMPDIR/missing.out" 2> "$TMPDIR/missing.err"
    grep -qF 'opencode: warning:' "$TMPDIR/missing.err"
    grep -qF 'missing or empty' "$TMPDIR/missing.err"
    grep -qF 'key=<unset>' "$TMPDIR/missing.out"
    grep -qF 'args=alpha' "$TMPDIR/missing.out"
    grep -qF 'OpenCode: missing secret' "$NOTIFY_LOG"

    : > "$NOTIFY_LOG"
    printf 'dummy-key\n' > "$HOME/.secrets/opencode-go-key"
    chmod 600 "$HOME/.secrets/opencode-go-key"
    ${wrapper}/bin/opencode beta > "$TMPDIR/present.out" 2> "$TMPDIR/present.err"
    test ! -s "$TMPDIR/present.err"
    grep -qF 'key=dummy-key' "$TMPDIR/present.out"
    grep -qF 'args=beta' "$TMPDIR/present.out"
    test ! -s "$NOTIFY_LOG"

    : > "$NOTIFY_LOG"
    : > "$HOME/.secrets/opencode-go-key"
    ${wrapper}/bin/opencode gamma > "$TMPDIR/empty.out" 2> "$TMPDIR/empty.err"
    grep -qF 'missing or empty' "$TMPDIR/empty.err"
    grep -qF 'key=<unset>' "$TMPDIR/empty.out"
    grep -qF 'OpenCode: missing secret' "$NOTIFY_LOG"

    mkdir -p "$TMPDIR/proj"
    printf 'dummy-key\n' > "$HOME/.secrets/opencode-go-key"
    chmod 600 "$HOME/.secrets/opencode-go-key"
    : > "$NOTIFY_LOG"
    ${wrapperMux}/bin/opencode "$TMPDIR/proj" > "$TMPDIR/mux.out" 2> "$TMPDIR/mux.err"
    grep -qF 'mux-args=client' "$TMPDIR/mux.out"
    grep -qF "$TMPDIR/proj" "$TMPDIR/mux.out"
    test ! -s "$TMPDIR/mux.err"

    ${wrapperMux}/bin/opencode session list > "$TMPDIR/subcommand.out" 2> "$TMPDIR/subcommand.err"
    grep -qF 'args=session list' "$TMPDIR/subcommand.out"
    test ! -s "$TMPDIR/subcommand.err"

    OPENCODE_MUX=0 ${wrapperMux}/bin/opencode "$TMPDIR/proj" > "$TMPDIR/standalone.out" 2> "$TMPDIR/standalone.err"
    grep -qF "args=$TMPDIR/proj" "$TMPDIR/standalone.out"
    test ! -s "$TMPDIR/standalone.err"

    ${wrapperMux}/bin/opencode --model test/model > "$TMPDIR/flag.out" 2> "$TMPDIR/flag.err"
    grep -qF 'args=--model test/model' "$TMPDIR/flag.out"
    test ! -s "$TMPDIR/flag.err"

    grep -qF '"{env:OPENCODE_GO_API_KEY}"' ${expectedConfig}
    if grep -qF '{file:~/.secrets/opencode-go-key}' ${expectedConfig}; then
      echo 'rendered opencode config still references the secret file' >&2
      exit 1
    fi

    touch $out
  ''
