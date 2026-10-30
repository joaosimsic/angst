{
  result,
  helpers,
  t,
}:

node:

let
  inherit (helpers) fail typeName toAttrs;
  inherit (result) ok collect traverse;

  field =
    name: desc: v: path:
    let
      p = path ++ [ name ];
      d = t.normalize desc;
    in
    if builtins.hasAttr name v then
      node d v.${name} p
    else if d._kind == "option" then
      ok d.default
    else
      fail p "missing required field";
in
{
  list =
    d: v: path:
    if !(builtins.isList v) then
      fail path "expected a list, got ${typeName v}"
    else
      traverse (item: node d.item item (path ++ [ "<item>" ])) v;

  attrs =
    d: v: path:
    if !(builtins.isAttrs v) then
      fail path "expected a set, got ${typeName v}"
    else
      let
        names = builtins.attrNames v;
      in
      result.mapOk (toAttrs names) (collect (map (k: node d.item v.${k} (path ++ [ k ])) names));

  set =
    d: v: path:
    if !(builtins.isAttrs v) then
      fail path "expected a set, got ${typeName v}"
    else
      let
        declared = builtins.attrNames d.fields;
        unknown = builtins.filter (k: !(d.fields ? ${k})) (builtins.attrNames v);
        fieldRs = map (name: field name d.fields.${name} v path) declared;
        unknownRs = map (k: fail (path ++ [ k ]) "unknown field") unknown;
      in
      result.mapOk (toAttrs declared) (collect (fieldRs ++ unknownRs));
}
