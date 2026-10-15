{ lib }:

let
  color = import ../color.nix { inherit lib; };
  inherit (color)
    stripHash
    hexToRgb
    hexToRgbInts
    relativeLuminance
    contrastRatio
    ensureContrast
    ;

  inherit (import ./assert.nix { inherit lib; })
    assertEq
    assertApprox
    assertTrue
    ;
in
[
  (assertEq "stripHash strips leading #" "abcdef" (stripHash "#abcdef"))
  (assertEq "stripHash leaves bare hex" "abcdef" (stripHash "abcdef"))
  (assertEq "hexToRgb black" "0 0 0" (hexToRgb "#000000"))
  (assertEq "hexToRgb white" "255 255 255" (hexToRgb "#ffffff"))
  (assertEq "hexToRgb lowercase" "10 10 10" (hexToRgb "#0a0a0a"))
  (assertEq "hexToRgb red channel" "255 0 0" (hexToRgb "#ff0000"))
  (assertEq "hexToRgb uppercase" "255 255 255" (hexToRgb "#FFFFFF"))
  (assertEq "hexToRgb bare" "255 255 255" (hexToRgb "ffffff"))
  (assertEq "hexToRgbInts" {
    r = 18;
    g = 52;
    b = 86;
  } (hexToRgbInts "#123456"))
  (assertApprox "relativeLuminance black" 0.0 (relativeLuminance "#000000"))
  (assertApprox "relativeLuminance white" 1.0 (relativeLuminance "#ffffff"))
  (assertApprox "contrastRatio white/black" 21.0 (contrastRatio "#ffffff" "#000000"))
  (assertApprox "contrastRatio same color" 1.0 (contrastRatio "#123456" "#123456"))
  (assertEq "ensureContrast keeps accessible fg" "#ffffff" (ensureContrast {
    fg = "#ffffff";
    bg = "#000000";
    fallback = "#ff0000";
    threshold = 4.5;
  }))
  (assertEq "ensureContrast falls back when low contrast" "#ff0000" (ensureContrast {
    fg = "#111111";
    bg = "#000000";
    fallback = "#ff0000";
    threshold = 4.5;
  }))
  (assertEq "ensureContrast default threshold" "#ffffff" (ensureContrast {
    fg = "#ffffff";
    bg = "#000000";
    fallback = "#ff0000";
  }))
  (assertTrue "contrastRatio symmetric" (
    contrastRatio "#ffffff" "#000000" == contrastRatio "#000000" "#ffffff"
  ))
]
