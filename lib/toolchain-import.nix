{ lib }:
path: fullArgs:
let
  f = import path;
  fArgs = builtins.functionArgs f;
  filtered =
    if fArgs ? __unfixed__ then
      fullArgs
    else
      lib.filterAttrs (n: _: builtins.hasAttr n fArgs) fullArgs;
in
f filtered
