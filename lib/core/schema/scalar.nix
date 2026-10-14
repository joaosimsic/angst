{
  result,
  helpers,
}:

node:

let
  inherit (helpers) fail typeName;
  inherit (result) ok err;
in
{
  leaf =
    d: v: path:
    if d.type.check v then ok v else fail path "expected ${d.type.description}, got ${typeName v}";

  option =
    d: v: path:
    if v == null then ok d.default else node d.inner v path;

  nullOr =
    d: v: path:
    if v == null then ok null else node d.inner v path;

  either =
    d: v: path:
    let
      left = node d.a v path;
    in
    if left.ok then
      left
    else
      let
        right = node d.b v path;
      in
      if right.ok then
        right
      else
        err {
          kind = "either";
          inherit path;
          message = "value matched neither branch";
          causes = [
            left.error
            right.error
          ];
        };
}
