{ lib }:

let
  inherit (lib) types mkOption;

  option = type: {
    _kind = "option";
    type = types.nullOr type;
    default = null;
  };

  optionOr = type: default: {
    _kind = "option";
    inherit type default;
  };

  makeAttr =
    attr:
    if attr ? _kind && attr._kind == "option" then
      mkOption (removeAttrs attr [ "_kind" ])
    else
      mkOption { type = attr; };

  set =
    attrs:
    types.submodule {
      options = lib.mapAttrs (_: makeAttr) attrs;
    };
in
{
  inherit set option optionOr;

  inherit (types)
    str
    bool
    int
    number
    path
    float
    enum
    listOf
    attrsOf
    either
    addCheck
    strMatching
    deferredModule
    ;
}
