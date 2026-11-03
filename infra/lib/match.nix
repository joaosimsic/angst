let
  logCodePattern = "([A-Z]+)[0-9]+$";

  parseLogCode = code: if builtins.isString code then builtins.match logCodePattern code else null;

  logCodePrefix =
    code:
    let
      matches = parseLogCode code;
    in
    if matches == null then null else builtins.head matches;
in
{
  inherit
    logCodePrefix
    parseLogCode
    ;
}
