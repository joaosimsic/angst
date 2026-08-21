{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.agents.cursor-cli.enable {
    home.file.".local/bin/cursor" = {
      executable = true;
      force = true;
      text = ''
        #!/bin/sh
        set -e
        if [ -z "''${CURSOR_API_KEY:-}" ] && [ -f "$HOME/.secrets/cursor-api-key" ]; then
          export CURSOR_API_KEY="$(cat "$HOME/.secrets/cursor-api-key")"
        fi

        find_cursor() {
          old_IFS="$IFS"; IFS=:
          for dir in $PATH; do
            [ -n "$dir" ] || continue
            c="$dir/cursor"
            if [ "$c" != "$HOME/.local/bin/cursor" ] && [ -x "$c" ]; then
              IFS="$old_IFS"; echo "$c"; return 0
            fi
          done
          IFS="$old_IFS"; return 1
        }

        OTHER="$(find_cursor || true)"
        if [ -n "$OTHER" ]; then
          exec "$OTHER" "$@"
        fi
        if [ "''${1:-}" != "agent" ]; then
          echo "Error: No Cursor IDE installation found. Use 'cursor agent'." 1>&2
          exit 1
        fi
        exec ${pkgs.cursor-cli}/bin/cursor-agent "$@"
      '';
    };
  };
}
