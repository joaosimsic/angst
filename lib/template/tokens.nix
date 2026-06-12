{ lib, themesLib, theme, fontFamily }:

let
  t = themesLib.get theme;
  inherit (import ./color.nix { inherit lib; }) lightenHex brighten;
in
t // {
  FONT_FAMILY = fontFamily;
  SURFACE = lightenHex t.BLACK 9;
  GREEN_BRIGHT = brighten t.GREEN;
  RED_BRIGHT = brighten t.RED;
  YELLOW_BRIGHT = brighten t.YELLOW;
  BLUE_BRIGHT = brighten t.BLUE;
  MAGENTA_BRIGHT = brighten t.MAGENTA;
  CYAN_BRIGHT = brighten t.CYAN;
}
