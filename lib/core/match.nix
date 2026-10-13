{ lib }:

{
  memberOf = names: lib.types.enum names;
  match =
    {
      names,
      cases,
      what ? "case",
    }:
    let
      missing = lib.subtractLists (builtins.attrNames cases) names;
      extra = lib.subtractLists names (builtins.attrNames cases);
    in
    if missing != [ ] then
      throw "missing ${what}(s): ${builtins.concatStringsSep ", " missing}"
    else if extra != [ ] then
      throw "unknown ${what}(s): ${builtins.concatStringsSep ", " extra}"
    else
      cases;
}
