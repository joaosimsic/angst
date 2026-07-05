{ lib, flakeSelf ? null, userConfig ? null }:

let
  flakePath = if flakeSelf != null then toString flakeSelf else "";
  hostFlake =
    if userConfig != null then "/host${userConfig.homeDirectory}/proj/angst/flake.nix" else null;
in
lib.hasPrefix "/host" flakePath
|| (hostFlake != null && builtins.pathExists hostFlake)
