{ lib }:

let
  themeSchema = import ../schema.nix { inherit lib; };
  result = import ../../../lib/core/result.nix { inherit lib; };
  match = import ../../../lib/core/match.nix { inherit lib; };
  types = import ../../../lib/core/types.nix { inherit lib; };
  engine = import ../../../lib/core/schema { inherit lib; };

  inherit (import ./assert.nix { inherit lib; })
    assertEq
    assertTrue
    assertThrows
    contains
    ;

  valid = {
    palette = {
      background = {
        base = "#000000";
        variant = "#010101";
      };
      surface = {
        base = "#020202";
        variant = "#030303";
      };
      foreground = {
        base = "#040404";
        variant = "#050505";
      };
      accent = {
        base = "#060606";
        variant = "#070707";
      };
      dim = "#080808";
    };
    ansi = {
      error = "#090909";
      warn = "#0a0a0a";
      info = "#0b0b0b";
      success = "#0c0c0c";
    };
  };

  validate =
    value:
    engine.validate {
      inherit (themeSchema) schema;
      inherit value;
    };

  formatted = r: result.format r.error;
  formattedOf = value: formatted (validate value);
in
[
  # --- happy path ---------------------------------------------------------
  (assertTrue "valid theme ok" (validate valid).ok)
  (assertTrue "valid theme reconstructs tokens" (
    (validate valid).value.palette.background.base == "#000000"
  ))
  (assertEq "optionOr default applied" 4.5 (validate valid).value.contrastThreshold)
  (assertEq "optionOr explicit value wins" 2
    (validate (valid // { contrastThreshold = 2; })).value.contrastThreshold
  )

  # --- structural failures ------------------------------------------------
  (assertTrue "missing field fails" (!(validate (builtins.removeAttrs valid [ "ansi" ])).ok))
  (assertTrue "missing field message" (
    contains "missing required field" (formattedOf (builtins.removeAttrs valid [ "ansi" ]))
  ))
  (assertTrue "unknown field fails" (!(validate (valid // { extra = true; })).ok))
  (assertTrue "unknown field message" (
    contains "unknown field" (formattedOf (valid // { extra = true; }))
  ))
  (assertTrue "non-set root fails" (!(validate "nope").ok))

  # --- scalar failures ----------------------------------------------------
  (assertTrue "invalid hex fails" (
    !(validate (
      valid
      // {
        palette = valid.palette // {
          dim = "#zzzzzz";
        };
      }
    )).ok
  ))
  (assertTrue "short hex fails" (
    !(validate (
      valid
      // {
        palette = valid.palette // {
          dim = "#fff";
        };
      }
    )).ok
  ))
  (assertTrue "missing hash fails" (
    !(validate (
      valid
      // {
        palette = valid.palette // {
          dim = "ffffff";
        };
      }
    )).ok
  ))

  # --- result helpers -----------------------------------------------------
  (assertTrue "format prefixes kind" (
    contains "error[schema]" (
      result.format {
        kind = "schema";
        message = "boom";
        path = [ ];
      }
    )
  ))
  (assertTrue "format carries context" (
    contains "file=themes/foo.nix" (
      result.format {
        kind = "schema";
        message = "boom";
        context = {
          file = "themes/foo.nix";
        };
      }
    )
  ))
  (assertEq "unwrapOr returns default on err" 7 (result.unwrapOr 7 (result.err "e")))
  (assertEq "unwrapOr returns value on ok" 1 (result.unwrapOr 7 (result.ok 1)))
  (assertTrue "collect joins failures" (
    let
      r = result.collect [
        (result.ok 1)
        (result.err {
          kind = "schema";
          message = "x";
          path = [ ];
        })
        (result.err {
          kind = "schema";
          message = "y";
          path = [ ];
        })
      ];
    in
    !r.ok && r.error.kind == "join" && lib.length r.error.causes == 2
  ))
  (assertTrue "collect ok passes through"
    (result.collect [
      (result.ok 1)
      (result.ok 2)
    ]).ok
  )
  (assertEq "tryCatch captures throw" "boom" (result.tryCatch "boom" (throw "nope")).error.kind)
  (assertEq "tryCatch passes value" 42 (result.tryCatch "boom" 42).value)

  # --- match exhaustiveness ----------------------------------------------
  (assertTrue "match.on valid" (
    (match.on {
      names = [
        "a"
        "b"
      ];
      cases = {
        a = 1;
        b = 2;
      };
    })
      "b" == 2
  ))
  (assertThrows "match.on missing case throws" (
    match.on {
      names = [
        "a"
        "b"
      ];
      cases = {
        a = 1;
      };
    }
  ))
  (assertThrows "match.on extra case throws" (
    match.on {
      names = [ "a" ];
      cases = {
        a = 1;
        b = 2;
      };
    }
  ))
  (assertThrows "match.on unknown kind throws" (
    match.on {
      names = types.kinds;
      cases = {
        leaf = 1;
      };
    }
  ))

  # --- schema.nix wrapper -------------------------------------------------
  (assertTrue "schema.validate returns ok result" (themeSchema.validate valid).ok)
  (assertEq "schema.validateOrThrow returns theme" "#000000"
    (themeSchema.validateOrThrow valid).palette.background.base
  )
  (assertThrows "schema.validateOrThrow throws on invalid" (
    themeSchema.validateOrThrow (builtins.removeAttrs valid [ "ansi" ])
  ))
]
