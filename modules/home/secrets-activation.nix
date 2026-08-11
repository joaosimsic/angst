{
  secretDefs,
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  present = lib.filterAttrs (name: _: config.sops.secrets ? ${name}) secretDefs;

  copySnippet =
    name:
    let
      def = present.${name};
    in
    ''
      SRC=${lib.escapeShellArg config.sops.secrets.${name}.path}
      if [ -f "$SRC" ]; then
        mkdir -p "$(dirname "$HOME/${def.target}")"
        cat "$SRC" > "$HOME/${def.target}"
        chmod ${def.mode or "0400"} "$HOME/${def.target}"
      fi
    '';

  copyScript = ''
    set -euo pipefail
  ''
  + lib.concatMapStrings copySnippet (builtins.attrNames present);

  copyScriptBin = pkgs.writeShellScript "secrets-to-home" copyScript;
in
lib.mkIf (present != { }) {
  home.activation.secrets-to-home = lib.hm.dag.entryAfter [ "secrets-ready" ] copyScript;

  systemd.user.services.secrets-to-home = {
    Unit = {
      Description = "angst: copy decrypted secrets to ~/.secrets";
      After = [ "sops-nix.service" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = copyScriptBin;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
