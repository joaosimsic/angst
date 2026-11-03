let
  match = import ../lib/match.nix;

  logCodesList = (builtins.fromJSON (builtins.readFile ./log-vocab.json)).logCodes;

  checkLogCode =
    code:
    let
      matches = match.parseLogCode code;
      prefix = if matches == null then null else builtins.head matches;
    in
    if !(builtins.isString code) || matches == null then
      throw "logger: `code` must look like PREFIXNNN (e.g. DESK001), got `${builtins.toJSON code}`"
    else if !(builtins.elem prefix logCodesList) then
      throw "logger: unknown code prefix `${toString prefix}`; expected one of ${builtins.concatStringsSep " " logCodesList}"
    else
      code;
in
{
  logCodes = logCodesList;

  logCodePrefix = code: match.logCodePrefix code;

  inherit checkLogCode;
}
