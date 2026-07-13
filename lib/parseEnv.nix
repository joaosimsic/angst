{ lib }:
path:
let
  content = builtins.readFile path;
  lines = lib.filter (line: line != "" && !lib.hasPrefix "#" line) (lib.splitString "\n" content);
  split = line:
    let
      idx = builtins.stringLength (builtins.head (lib.splitString "=" line));
      name = lib.substring 0 idx line;
      value = lib.substring (idx + 1) (-1) line;
    in
    lib.nameValuePair name value;
in
lib.listToAttrs (map split lines)
