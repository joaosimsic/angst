{ lib }:

let
  stripHash = hex: if lib.hasPrefix "#" hex then lib.removePrefix "#" hex else hex;

  hexValues = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };

  hexToRgb =
    hex:
    let
      val = stripHash hex;
      hexByte =
        offset:
        let
          hi = lib.toLower (lib.substring offset 1 val);
          lo = lib.toLower (lib.substring (offset + 1) 1 val);
        in
        hexValues.${hi} * 16 + hexValues.${lo};
    in
    "${toString (hexByte 0)} ${toString (hexByte 2)} ${toString (hexByte 4)}";

  hexToRgbInts =
    hex:
    let
      val = stripHash hex;
    in
    {
      r =
        hexValues.${lib.toLower (lib.substring 0 1 val)} * 16
        + hexValues.${lib.toLower (lib.substring 1 1 val)};
      g =
        hexValues.${lib.toLower (lib.substring 2 1 val)} * 16
        + hexValues.${lib.toLower (lib.substring 3 1 val)};
      b =
        hexValues.${lib.toLower (lib.substring 4 1 val)} * 16
        + hexValues.${lib.toLower (lib.substring 5 1 val)};
    };

  srgbToLinearChannel =
    c:
    let
      cNorm = c / 255.0;
    in
    if cNorm <= 0.04045 then
      cNorm / 12.92
    else
      (
        let
          x = (cNorm + 0.055) / 1.055;
        in
        x * x
      );

  relativeLuminance =
    hex:
    let
      rgb = hexToRgbInts (stripHash hex);
    in
    0.2126 * srgbToLinearChannel rgb.r
    + 0.7152 * srgbToLinearChannel rgb.g
    + 0.0722 * srgbToLinearChannel rgb.b;

  contrastRatio =
    hex1: hex2:
    let
      l1 = relativeLuminance hex1;
      l2 = relativeLuminance hex2;
      lighter = if l1 >= l2 then l1 else l2;
      darker = if l1 >= l2 then l2 else l1;
    in
    (lighter + 0.05) / (darker + 0.05);

  ensureContrast =
    {
      fg,
      bg,
      fallback,
      threshold ? 4.5,
    }:
    if contrastRatio fg bg >= threshold then fg else fallback;
in
{
  inherit
    stripHash
    hexToRgb
    hexToRgbInts
    relativeLuminance
    contrastRatio
    ensureContrast
    ;
}
