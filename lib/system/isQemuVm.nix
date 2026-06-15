{ lib, flakeSelf ? null }:

flakeSelf != null && builtins.pathExists (flakeSelf + "/.vm")
