{ lib }:

let
  guard =
    {
      names,
      cases,
      what ? "variant",
    }:
    let
      missing = lib.subtractLists (builtins.attrNames cases) names;
      extra = lib.subtractLists names (builtins.attrNames cases);
    in
    if missing != [ ] then
      throw "non-exhaustive match on ${what}: missing ${builtins.concatStringsSep ", " missing}"
    else if extra != [ ] then
      throw "invalid match on ${what}: unknown ${builtins.concatStringsSep ", " extra}"
    else
      cases;

  match =
    {
      names,
      cases,
      what ? "variant",
    }:
    guard { inherit names cases what; };

  on =
    {
      names,
      cases,
      what ? "variant",
    }:
    let
      c = guard { inherit names cases what; };
    in
    builtins.seq c (tag: c.${tag});

  memberOf = names: lib.types.enum names;
in
{
  inherit match on memberOf;
}
