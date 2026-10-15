{ themeSys, themeName }:
let
  t = themeSys.get themeName;
in
[
  {
    path = "domains/embedded/vial/config/theme.json";
    text = builtins.toJSON {
      inherit (t) palette ansi;
    };
  }
]
