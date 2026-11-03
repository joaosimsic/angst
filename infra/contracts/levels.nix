let
  error = import ../lib/error.nix;

  logLevelsList = (builtins.fromJSON (builtins.readFile ./log-vocab.json)).logLevels;

  checkLogLevel =
    level:
    if builtins.elem level logLevelsList then
      level
    else
      error.throwError {
        kind = "LOG";
        message = "logger: unknown `level`";
        context = {
          inherit level;
          expected = logLevelsList;
        };
      };
in
{
  logLevels = logLevelsList;

  isLogLevel = level: builtins.elem level logLevelsList;

  inherit checkLogLevel;
}
