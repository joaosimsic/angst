{ lib, templatePath, tokens }:

let
  inherit (lib) attrNames foldl';
  template = builtins.readFile templatePath;
in
foldl'
  (acc: name:
    builtins.replaceStrings [ "{{${name}}}" ] [ tokens.${name} ] acc
  )
  template
  (attrNames tokens)
