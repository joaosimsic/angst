{ lib, result }:

let
  typeName =
    v:
    if builtins.isString v then
      "string"
    else if builtins.isInt v then
      "int"
    else if builtins.isFloat v then
      "float"
    else if builtins.isBool v then
      "bool"
    else if builtins.isList v then
      "list"
    else if builtins.isAttrs v then
      "set"
    else if builtins.isFunction v then
      "function"
    else
      builtins.typeOf v;

  toAttrs =
    names: vals:
    builtins.listToAttrs (
      lib.imap0 (i: name: {
        inherit name;
        value = builtins.elemAt vals i;
      }) names
    );

  fail =
    path: message:
    result.err {
      kind = "schema";
      inherit path message;
    };
in
{
  inherit typeName toAttrs fail;
}
