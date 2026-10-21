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

  miasma = themeSys.get "miasma";
in
[
  (assertTrue "at least 8 bundled themes" (lib.length themeNames >= 8))
  (assertTrue "miasma present" (themeSys.themes ? miasma))
  (assertEq "default is miasma" "miasma" themeSys.default)
  (assertEq "miasma background stripped" "272727" miasma.palette.background.base)
  (assertEq "miasma background RGB" "39 39 39" miasma."_palette_background_base_RGB")
]
++ lib.concatMap checkTheme themeNames
