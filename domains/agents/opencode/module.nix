{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.agents.opencode.enable (
    lib.mkMerge [
      {
        home.packages = [ pkgs.opencode ];
      }
      (lib.mkIf ((config.sops or { }).secrets or { } ? opencodeGoKey) {
        home.activation.opencodeGoKey = lib.hm.dag.entryAfter [ "secrets-ready" ] ''
          set -euo pipefail
          KEY=$(cat ${lib.escapeShellArg config.sops.secrets.opencodeGoKey.path})
          SECRETS_DIR="$HOME/.secrets"
          KEY_FILE="$SECRETS_DIR/opencode-go-key"

          mkdir -p "$SECRETS_DIR"
          echo -n "$KEY" > "$KEY_FILE"
          chmod 600 "$KEY_FILE"
          unset KEY
        '';
      })
    ]
  );
}
