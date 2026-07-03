{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf;
  cfg = config.domains.terminal.zellij;
in
{
  config = mkIf cfg.enable {
    home.packages = [ pkgs.zellij ];

    home.activation.seedZellijPermissions = lib.hm.dag.entryAfter [
      "domain-terminal-zellij"
      "writeBoundary"
    ] ''
      PERMS_DIR="${config.home.homeDirectory}/.cache/zellij"
      PERMS_FILE="$PERMS_DIR/permissions.kdl"

      ZJSTATUS_URL="https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm"
      VIMNAV_URL="https://github.com/hiasr/vim-zellij-navigator/releases/download/0.3.0/vim-zellij-navigator.wasm"

      $DRY_RUN_CMD mkdir -p "$PERMS_DIR"

      seed_plugin() {
        local url="$1"
        shift
        if [ -f "$PERMS_FILE" ] && grep -qF "$url" "$PERMS_FILE" 2>/dev/null; then
          return
        fi
        if [ -z "$DRY_RUN_CMD" ]; then
          {
            printf '    "%s" {\n' "$url"
            for perm in "$@"; do
              printf '        %s\n' "$perm"
            done
            printf '    }\n'
          } >> "$PERMS_FILE"
          echo "zellij: pre-seeded permissions for $(basename "$url")"
        else
          echo "Would seed permissions for $(basename "$url")"
        fi
      }

      seed_plugin "$ZJSTATUS_URL" \
        ReadApplicationState \
        ChangeApplicationState \
        RunCommands

      seed_plugin "$VIMNAV_URL" \
        WriteToStdin \
        ChangeApplicationState \
        ReadApplicationState
    '';
  };
}
