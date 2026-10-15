{ lib, themeSys }:

let
  inherit (import ./assert.nix { inherit lib; })
    assertEq
    assertTrue
    assertMatch
    ;

  themeNames = lib.attrNames themeSys.themes;

  tokenPaths = [
    "palette.background.base"
    "palette.background.variant"
    "palette.surface.base"
    "palette.surface.variant"
    "palette.foreground.base"
    "palette.foreground.variant"
    "palette.accent.base"
    "palette.accent.variant"
    "palette.dim"
    "ansi.error"
    "ansi.warn"
    "ansi.info"
    "ansi.success"
  ];

  checkTheme =
    name:
    let
      t = themeSys.get name;
    in
    map (p: assertTrue "${name}: token ${p}" (lib.hasAttrByPath (lib.splitString "." p) t)) tokenPaths
    ++ [
      (assertTrue "${name}: strips leading #" (!(lib.hasPrefix "#" t.palette.background.base)))
      (assertTrue "${name}: withRgb adds palette.background.base_RGB" (
        t ? "_palette_background_base_RGB"
      ))
      (assertMatch "${name}: RGB is int triple" "[0-9]+ [0-9]+ [0-9]+" t."_palette_background_base_RGB")
      (assertTrue "${name}: colorScheme set" (
        builtins.elem t.colorScheme [
          "dark"
          "light"
        ]
      ))
      (assertTrue "${name}: isDark is bool" (builtins.isBool t.isDark))
    ];

  monochrome = themeSys.get "monochrome";
in
[
  (assertTrue "at least 9 bundled themes" (lib.length themeNames >= 9))
  (assertTrue "monochrome present" (themeSys.themes ? monochrome))
  (assertEq "default is monochrome" "monochrome" themeSys.default)
  (assertEq "monochrome background stripped" "0a0a0a" monochrome.palette.background.base)
  (assertEq "monochrome background RGB" "10 10 10" monochrome."_palette_background_base_RGB")
]
++ lib.concatMap checkTheme themeNames
