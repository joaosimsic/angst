let
  error = import ../lib/error.nix;
  match = import ../lib/match.nix;

  logCodesList = (builtins.fromJSON (builtins.readFile ./log-vocab.json)).logCodes;

  checkLogCode =
    code:
    let
      matches = match.parseLogCode code;
      prefix = if matches == null then null else builtins.head matches;
    in
    if !(builtins.isString code) || prefix == null then
      error.throwError {
        kind = "LOG";
        message = "logger: `code` must look like PREFIXNNN (e.g. DESK001)";
        context = { inherit code; };
      }
    else if !(builtins.elem prefix logCodesList) then
      error.throwError {
        kind = "LOG";
        message = "logger: unknown code prefix";
        context = {
          inherit code prefix;
          expected = logCodesList;
        };
      }
    else
      code;
in
{
  logCodes = logCodesList;

  logCodePrefix = code: match.logCodePrefix code;

  inherit checkLogCode;
}
