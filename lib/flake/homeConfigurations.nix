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
  envPath = ../../user.env;
  pwd = builtins.getEnv "PWD";
  pwdEnvPath = if pwd != "" then pwd + "/user.env" else "";
  homeEnvPath = builtins.getEnv "HOME" + "/proj/angst/user.env";
  userEnv = let
    fromFile = if builtins.pathExists envPath then parseEnvFile envPath
      else if builtins.pathExists homeEnvPath then parseEnvFile homeEnvPath
      else if pwdEnvPath != "" && builtins.pathExists pwdEnvPath then parseEnvFile pwdEnvPath
      else { };
  in fromFile // (
    let u = builtins.getEnv "ANGST_USERNAME"; h = builtins.getEnv "ANGST_HOST"; in
    (if h != "" then { HOST = h; } else {}) // (if u != "" then { USERNAME = u; } else {})
  );

  effectiveUsername = let
    envUser = builtins.getEnv "ANGST_USERNAME";
  in
    if envUser != "" then envUser
    else userEnv.USERNAME or (loadHost testHostname).user.username;

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
