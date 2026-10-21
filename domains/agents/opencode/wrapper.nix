{
  pkgs,
  lib ? pkgs.lib,
  opencodePackage,
  muxPackage ? null,
  muxEnabled ? false,
  muxFallback ? true,
  notifySend ? pkgs.libnotify,
}:

let
  muxBlock = lib.optionalString (muxEnabled && muxPackage != null) ''
    export OPENCODE_MUX_FALLBACK="${if muxFallback then "1" else "0"}"

    for arg in "$@"; do
      case "$arg" in
        --model|--model=*|-m|--agent|--agent=*|--prompt|--prompt=*|--auto|--pure|--port|--port=*|--hostname|--hostname=*|--mdns|--mdns=*|--mdns-domain|--mdns-domain=*|--cors|--cors=*)
          exec ${opencodePackage}/bin/opencode "$@"
          ;;
      esac
    done

    if [ "''${OPENCODE_MUX:-1}" != "0" ]; then
      case "''${1:-}" in
        "" )
          exec ${muxPackage}/bin/opencode-mux client "$@"
          ;;
        --help|-h|--version|-v|agent|auth|completion|acp|mcp|serve|web|run|debug|providers|models|stats|export|import|github|pr|session|plugin|db|upgrade|uninstall|attach)
          ;;
        --*)
          exec ${muxPackage}/bin/opencode-mux client "$@"
          ;;
        *)
          if [ -d "$1" ]; then
            exec ${muxPackage}/bin/opencode-mux client "$@"
          fi
          ;;
      esac
    fi
  '';
in
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

    ${muxBlock}
    exec ${opencodePackage}/bin/opencode "$@"
  '';
}
