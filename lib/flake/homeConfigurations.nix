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
    let u = builtins.getEnv "ANGST_USERNAME"; in if u != "" then { USERNAME = u; } else {}
  );

  effectiveUsername =
    h:
    let envUser = builtins.getEnv "ANGST_USERNAME"; in
    if envUser != "" then envUser
    else userEnv.USERNAME or (loadHost h).user.username;

  perHost = lib.listToAttrs (
    map (
      h:
      let
        user = (loadHost h).user;
      in
      {
        name = "${effectiveUsername h}@${h}";
        value = mkHome h;
      }
    ) hosts
  );

  testUser = effectiveUsername testHostname;
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
