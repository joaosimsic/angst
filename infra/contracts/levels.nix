let
  types = import ../lib/types.nix;

  logLevelsList = (builtins.fromJSON (builtins.readFile ./log-vocab.json)).logLevels;

  checkLogLevel =
    level:
    if builtins.elem level logLevelsList then
      types.ok level
    else
      types.err {
        kind = "level";
        message = "logger: `level` must be one of ${builtins.concatStringsSep " " logLevelsList}, got `${builtins.toJSON level}`";
        context = {
          field = "level";
        };
      };
in
{
  logLevels = logLevelsList;

  isLogLevel = level: builtins.elem level logLevelsList;

  inherit checkLogLevel;

  assertLogLevel = level: types.unwrap (checkLogLevel level);
}
