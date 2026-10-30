let
  types = import ../lib/types.nix;
  match = import ../lib/match.nix;

  logCodesList = (builtins.fromJSON (builtins.readFile ./log-vocab.json)).logCodes;

  checkLogCode =
    code:
    let
      m = match.parseLogCode code;
      prefix = if m == null then null else builtins.head m;
      shape = types.check (builtins.isString code && m != null) {
        kind = "code";
        message = "logger: `code` must look like PREFIXNNN (e.g. DESK001), got `${builtins.toJSON code}`";
        context = {
          field = "code";
        };
      };
      known = types.check (m == null || builtins.elem prefix logCodesList) {
        kind = "code";
        message = "logger: unknown code prefix `${toString prefix}`; expected one of ${builtins.concatStringsSep " " logCodesList}";
        context = {
          field = "code";
        };
      };
    in
    types.mapOk (_: code) (
      types.collect [
        shape
        known
      ]
    );
in
{
  logCodes = logCodesList;

  logCodePrefix = code: match.logCodePrefix code;

  inherit checkLogCode;

  assertLogCode = code: types.unwrap (checkLogCode code);
}
