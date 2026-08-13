{
  lib,
  flakeSelf ? null,
  userConfig ? null,
}:

let
  repoPath = ".config/angst";
  flakePath = if flakeSelf != null then toString flakeSelf else "";
  hostFlake =
    if userConfig != null then "/host${userConfig.homeDirectory}/${repoPath}/flake.nix" else null;
in
lib.hasPrefix "/host" flakePath || (hostFlake != null && builtins.pathExists hostFlake)
