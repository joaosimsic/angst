{
  lib,
  hosts,
  loadHost,
  mkHome,
  mkHomeWithExtraModules,
  themeContext,
}:

let
  inherit (themeContext) overrideTheme testHostname;

  parseEnvFile = import ../parseEnv.nix { inherit lib; };
  envPath = ../../user.env;
  userEnv = (if builtins.pathExists envPath then parseEnvFile envPath else { }) // (
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
