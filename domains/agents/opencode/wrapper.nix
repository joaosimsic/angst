{
  pkgs,
  opencodePackage,
  notifySend ? pkgs.libnotify,
}:

pkgs.writeShellApplication {
  name = "opencode";
  runtimeInputs = [ notifySend ];
  text = ''
    secret="$HOME/.secrets/opencode-go-key"
    key=""
    if [ -r "$secret" ]; then
      key="$(< "$secret")"
    fi

    if [ -n "$key" ]; then
      export OPENCODE_GO_API_KEY="$key"
    else
      printf 'opencode: warning: %s is missing or empty\n' "$secret" >&2
      notify-send -u normal -a opencode "OpenCode: missing secret" "$secret is missing or empty" >/dev/null 2>&1 || true
    fi

    exec ${opencodePackage}/bin/opencode "$@"
  '';
}
