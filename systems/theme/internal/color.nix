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

  intToHexByte =
    n:
    let
      hexChars = "0123456789abcdef";
      hi = builtins.div n 16;
      lo = n - hi * 16;
    in
    lib.substring hi 1 hexChars + lib.substring lo 1 hexChars;

  mix =
    {
      from,
      to,
      weight,
    }:
    let
      a = hexToRgbInts from;
      b = hexToRgbInts to;
      w =
        if weight < 0.0 then
          0.0
        else if weight > 1.0 then
          1.0
        else
          weight;
      channel =
        fromChannel: toChannel:
        intToHexByte (builtins.floor (fromChannel + (toChannel - fromChannel) * w + 0.5));
    in
    channel a.r b.r + channel a.g b.g + channel a.b b.b;

  # sRGB -> linear per WCAG (exponent 2.4). Nix has no pow builtin,
  # so x^2.4 is computed as x^2 * fifthRoot(x^2) via Newton iteration.
  fifthRoot = y: lib.foldl' (z: _: (4 * z + y / (z * z * z * z)) / 5) 1.0 (lib.range 1 10);

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
          sq = x * x;
        in
        sq * fifthRoot sq
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

  # Ordered candidate pick: first candidate passing threshold wins
  # (preserves designer intent); if none pass, the highest-ratio
  # candidate wins instead of a blind fallback that may also fail.
  pickContrast =
    {
      candidates,
      bg,
      threshold ? 4.5,
    }:
    let
      ranked = lib.sort (a: b: a.ratio > b.ratio) (
        map (c: {
          value = c;
          ratio = contrastRatio c bg;
        }) candidates
      );
      orderedPassing = lib.filter (c: contrastRatio c bg >= threshold) candidates;
    in
    if orderedPassing != [ ] then builtins.head orderedPassing else (builtins.head ranked).value;
in
{
  inherit
    stripHash
    hexToRgb
    hexToRgbInts
    intToHexByte
    mix
    relativeLuminance
    contrastRatio
    ensureContrast
    pickContrast
    ;
}
