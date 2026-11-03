let
  logLevelsList = (builtins.fromJSON (builtins.readFile ./log-vocab.json)).logLevels;

  checkLogLevel =
    level:
    if builtins.elem level logLevelsList then
      level
    else
      throw "logger: `level` must be one of ${builtins.concatStringsSep " " logLevelsList}, got `${builtins.toJSON level}`";
in
{
  logLevels = logLevelsList;

  isLogLevel = level: builtins.elem level logLevelsList;

  inherit checkLogLevel;
}
