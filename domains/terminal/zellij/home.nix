{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf;
  cfg = config.domains.terminal.zellij;
  plugins = {
    zjstatus = pkgs.fetchurl {
      url = "https://github.com/dj95/zjstatus/releases/download/v0.25.0/zjstatus.wasm";
      hash = "sha256-KCzqshnlbhkIyfrDOQckH+bD4e99hfqrPl9DjO+HuP4=";
    };
    vimNavigator = pkgs.fetchurl {
      url = "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.3.0/vim-zellij-navigator.wasm";
      hash = "sha256-d+Wi9i98GmmMryV0ST1ddVh+D9h3z7o0xIyvcxwkxY0=";
    };
  };
in
{
  config = mkIf cfg.enable {
    home.packages = [ pkgs.zellij ];

    xdg.configFile = {
      "zellij/plugins/zjstatus.wasm".source = plugins.zjstatus;
      "zellij/plugins/vim-zellij-navigator.wasm".source = plugins.vimNavigator;
    };

    home.activation.seedZellijPermissions =
      lib.hm.dag.entryAfter
        [
          "domain-terminal-zellij"
          "writeBoundary"
        ]
        ''
          PERMS_DIR="${config.home.homeDirectory}/.cache/zellij"
          PERMS_FILE="$PERMS_DIR/permissions.kdl"

          PLUGIN_DIR="${config.home.homeDirectory}/.config/zellij/plugins"
          ZJSTATUS_PLUGIN="$PLUGIN_DIR/zjstatus.wasm"
          VIMNAV_PLUGIN="$PLUGIN_DIR/vim-zellij-navigator.wasm"

          $DRY_RUN_CMD mkdir -p "$PERMS_DIR"

          seed_plugin() {
            local plugin="$1"
            shift
            if [ -f "$PERMS_FILE" ] && grep -qF "$plugin" "$PERMS_FILE" 2>/dev/null; then
              return
            fi
            if [ -z "$DRY_RUN_CMD" ]; then
              {
                printf '    "%s" {\n' "$plugin"
                for perm in "$@"; do
                  printf '        %s\n' "$perm"
                done
                printf '    }\n'
              } >> "$PERMS_FILE"
              echo "zellij: pre-seeded permissions for $(basename "$plugin")"
            else
              echo "Would seed permissions for $(basename "$plugin")"
            fi
          }

          seed_plugin "$ZJSTATUS_PLUGIN" \
            ReadApplicationState \
            ChangeApplicationState \
            RunCommands

          seed_plugin "$VIMNAV_PLUGIN" \
            WriteToStdin \
            ChangeApplicationState \
            ReadApplicationState
        '';
  };
}
