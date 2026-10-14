{ lib }:

let
  inherit (lib) types;

  leaf = type: {
    _kind = "leaf";
    inherit type;
  };
  normalize = x: if builtins.isAttrs x && (x ? _kind) then x else leaf x;
  underlying = x: (normalize x).type or null;

  option = inner: {
    _kind = "option";
    inner = normalize inner;
    default = null;
  };
  optionOr = inner: default: {
    _kind = "option";
    inner = normalize inner;
    inherit default;
  };
  nullOr = inner: {
    _kind = "nullOr";
    inner = normalize inner;
  };
  set = fields: {
    _kind = "set";
    inherit fields;
  };
  listOf = item: {
    _kind = "list";
    item = normalize item;
  };
  attrsOf = item: {
    _kind = "attrs";
    item = normalize item;
  };
  either = a: b: {
    _kind = "either";
    a = normalize a;
    b = normalize b;
  };

  addCheck = base: f: leaf (types.addCheck (underlying base) f);
  strMatching = pattern: leaf (types.strMatching pattern);
  enum = names: leaf (types.enum names);

  str = leaf types.str;
  bool = leaf types.bool;
  int = leaf types.int;
  number = leaf types.number;
  path = leaf types.path;
  float = leaf types.float;
  deferredModule = leaf types.deferredModule;

  kinds = [
    "leaf"
    "option"
    "nullOr"
    "list"
    "attrs"
    "set"
    "either"
  ];
in
{
  inherit
    option
    optionOr
    nullOr
    set
    listOf
    attrsOf
    either
    addCheck
    strMatching
    enum
    str
    bool
    int
    number
    path
    float
    deferredModule
    leaf
    normalize
    underlying
    kinds
    ;
}
