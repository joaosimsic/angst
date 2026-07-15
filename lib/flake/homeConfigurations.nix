{
  lib,
  hosts,
  loadHost,
  mkHome,
  mkHomeWithExtraModules,
  themeContext,
}:

let
  inherit (themeContext) overrideTheme;
  testHostname = userEnv.HOST or themeContext.testHostname;

  parseEnvFile = import ../parseEnv.nix { inherit lib; };
  homeEnvPath = builtins.getEnv "HOME" + "/proj/angst/user.env";
  userEnv = let
    fromFile = if builtins.pathExists homeEnvPath then parseEnvFile homeEnvPath
      else { };
  in fromFile // (
    let u = builtins.getEnv "ANGST_USERNAME"; in if u != "" then { USERNAME = u; } else {}
  );

  effectiveUsername = let
    envUser = builtins.getEnv "ANGST_USERNAME";
  in
    if envUser != "" then envUser
    else userEnv.USERNAME;

  perHost = lib.listToAttrs (
    map (
      h:
      {
        name = "${effectiveUsername}@${h}";
        value = mkHome h;
      }
    ) hosts
  );

  testUser = effectiveUsername;
in
perHost
// {
  "${testUser}" = mkHome testHostname;
  "${testUser}-theme-override-test" =
    mkHomeWithExtraModules testHostname
      [
        { theme = overrideTheme; }
      ];
}
