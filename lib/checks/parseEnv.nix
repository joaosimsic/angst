{
  lib,
  pkgs,
}:

let
  parseEnv = import ../parseEnv.nix { inherit lib; };

  test1File = pkgs.writeText "test-env1" ''
    PASSWORD=$6$abc123
    THEME=dark
  '';
  result1 = parseEnv test1File;

  test2File = pkgs.writeText "test-env2" ''
    # This is a comment

    KEY=value
  '';
  result2 = parseEnv test2File;

  test3File = pkgs.writeText "test-env3" ''
    PASSWORD=$6$salt$hashhash$more
  '';
  result3 = parseEnv test3File;

  check1 = assert result1.PASSWORD == "$6$abc123"; "  PASSWORD parsed: ok";
  check2 = assert result1.THEME == "dark"; "  THEME parsed: ok";
  check3 = assert !(builtins.hasAttr "#" result2); "  comments ignored: ok";
  check4 = assert result2.KEY == "value"; "  empty lines skipped: ok";
  check5 = assert result3.PASSWORD == "$6$salt$hashhash$more"; "  dollar signs in value: ok";
  check6 = assert builtins.attrNames result1 == [ "PASSWORD" "THEME" ]; "  key set: ok";
in
pkgs.writeText "check-parse-env" (
  builtins.concatStringsSep "\n" ([
    "parseEnv checks:"
    check1
    check2
    check3
    check4
    check5
    check6
  ])
)
