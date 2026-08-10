{
  secretDefs,
}:

{ config, lib, ... }:

let
  present = lib.filterAttrs (name: _: config.sops.secrets ? ${name}) secretDefs;
in
lib.mkIf (present != { }) {
  home.activation.secrets-to-home = lib.hm.dag.entryAfter [ "secrets-ready" ] (
    ''
      set -euo pipefail
    ''
    + lib.concatMapStrings (
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
      ''
    ) (builtins.attrNames present)
  );
}
