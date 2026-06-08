{ lib, templatePath, tokens }:

let
  inherit (lib) attrNames concatStringsSep foldl';

  templatePlaceholders = import ./templatePlaceholders.nix { inherit lib; };

  template = builtins.readFile templatePath;

  rendered =
    foldl'
      (acc: name:
        builtins.replaceStrings [ "{{${name}}}" ] [ tokens.${name} ] acc
      )
      template
      (attrNames tokens);

  leftover = templatePlaceholders.extractPlaceholders rendered;
in
if leftover != [ ] then
  builtins.throw ''
    Template ${templatePath} has unresolved placeholders: ${concatStringsSep ", " leftover}
    Available theme keys: ${concatStringsSep ", " (attrNames tokens)}
  ''
else
  rendered
