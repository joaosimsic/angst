{ lib }:

let
  inherit (lib) concatLists unique;
in
rec {
  extractPlaceholders =
    text:
    let
      parts = lib.splitString "{{" text;
      fromPart =
        part:
        let
          endParts = lib.splitString "}}" part;
        in
        if lib.length endParts >= 2 then
          let
            token = builtins.elemAt endParts 0;
            rest = lib.concatStringsSep "}}" (lib.drop 1 endParts);
          in
          if builtins.match "[A-Z][A-Z0-9_]*" token != null then
            [ token ] ++ extractPlaceholders rest
          else
            extractPlaceholders rest
        else
          [ ];
    in
    unique (concatLists (map fromPart (lib.drop 1 parts)));
}
