{ lib }:

let
  t = import ../types.nix { inherit lib; };
  result = import ../result.nix { inherit lib; };
  match = import ../match.nix { inherit lib; };
  helpers = import ./helpers.nix { inherit lib result; };

  mkScalar = import ./scalar.nix { inherit result helpers; };
  mkStructural = import ./structural.nix {
    inherit
      result
      helpers
      t
      ;
  };

  handlers = mkScalar node // mkStructural node;
  dispatch = match.on {
    names = t.kinds;
    what = "schema node kind";
    cases = handlers;
  };
  node =
    desc: v: path:
    let
      d = t.normalize desc;
    in
    (dispatch d._kind) d v path;

  validate =
    {
      schema,
      value,
      file ? null,
    }:
    let
      r = node {
        _kind = "set";
        fields = schema;
      } value [ ];
    in
    if file == null then r else result.withContext { inherit file; } r;
in
{
  inherit validate;
}
