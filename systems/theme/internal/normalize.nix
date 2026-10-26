{ lib, stripHash, hexToRgb }:

let
  normalizeSub = sub: lib.mapAttrs (_: stripHash) sub;

  normalizeTheme =
    theme:
    let
      p = theme.palette;
    in
    {
      palette = {
        background = normalizeSub p.background;
        surface = normalizeSub p.surface;
        foreground = normalizeSub p.foreground;
        accent = normalizeSub p.accent;
        dim = stripHash p.dim;
      };
      ansi = lib.mapAttrs (_: stripHash) theme.ansi;
    }
    // builtins.removeAttrs theme [
      "palette"
      "ansi"
    ];

  withRgb =
    theme:
    let
      isHex = value: builtins.match "[0-9a-fA-F]{6}" value != null;
      walk =
        prefix: value:
        if builtins.isString value then
          if isHex value then { "${prefix}_RGB" = hexToRgb value; } else { }
        else if builtins.isAttrs value then
          lib.concatMapAttrs (key: sub: walk "${prefix}_${key}" sub) value
        else if builtins.isFunction value then
          { }
        else
          { };
    in
    theme // walk "" theme;
in
{
  inherit
    normalizeTheme
    withRgb
    ;
}
