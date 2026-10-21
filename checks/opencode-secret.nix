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

  wrapper = import ../domains/agents/opencode/wrapper.nix {
    inherit pkgs;
    opencodePackage = fakeOpencode;
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

    grep -qF '"{env:OPENCODE_GO_API_KEY}"' ${expectedConfig}
    if grep -qF '{file:~/.secrets/opencode-go-key}' ${expectedConfig}; then
      echo 'rendered opencode config still references the secret file' >&2
      exit 1
    fi

    touch $out
  ''
