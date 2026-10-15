{ lib }:

let
  render = v: if builtins.isString v then v else builtins.toJSON v;

  approxEq =
    eps: a: b:
    let
      d = a - b;
    in
    (if d < 0 then -d else d) < eps;

  assertEq =
    label: expected: actual:
    if expected == actual then
      "  ${label}: ok"
    else
      throw "assertEq failed [${label}]: expected ${render expected}, got ${render actual}";

  assertTrue = label: cond: if cond then "  ${label}: ok" else throw "assertTrue failed [${label}]";

  assertApprox =
    label: expected: actual:
    if approxEq 0.0001 expected actual then
      "  ${label}: ok"
    else
      throw "assertApprox failed [${label}]: expected ${render expected}, got ${render actual}";

  assertThrows =
    label: expr:
    let
      r = builtins.tryEval (builtins.deepSeq expr expr);
    in
    if r.success then throw "assertThrows failed [${label}]: expected a throw" else "  ${label}: ok";

  assertMatch =
    label: pattern: value:
    if builtins.match pattern value != null then
      "  ${label}: ok"
    else
      throw "assertMatch failed [${label}]: ${render value} did not match ${pattern}";

  contains = needle: haystack: lib.hasInfix needle haystack;
in
{
  inherit
    assertEq
    assertTrue
    assertApprox
    assertThrows
    assertMatch
    contains
    approxEq
    ;
}
