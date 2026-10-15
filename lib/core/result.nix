{ lib }:

let
  normalize =
    e:
    if builtins.isString e then
      {
        kind = "error";
        message = e;
      }
    else
      e;

  ok = value: {
    _result = true;
    ok = true;
    inherit value;
  };

  err = error: {
    _result = true;
    ok = false;
    error = normalize error;
  };

  isResult = r: builtins.isAttrs r && (r._result or false);
  isOk = r: r.ok;
  isErr = r: !r.ok;
  is = kind: r: !r.ok && (r.error.kind or null) == kind;

  mapOk = f: r: if r.ok then ok (f r.value) else r;
  mapError = f: r: if r.ok then r else err (f r.error);
  andThen = f: r: if r.ok then f r.value else r;

  withContext =
    ctx: r: if r.ok then r else err (r.error // { context = (r.error.context or { }) // ctx; });

  collect =
    rs:
    let
      failed = builtins.filter (r: !r.ok) rs;
    in
    if failed == [ ] then
      ok (map (r: r.value) rs)
    else
      let
        causes = lib.concatMap (
          r:
          let
            e = r.error;
          in
          if e.kind == "join" && e ? causes then e.causes else [ e ]
        ) failed;
      in
      err {
        kind = "join";
        message = "${toString (builtins.length causes)} error(s)";
        inherit causes;
      };

  sequence = collect;

  traverse = f: xs: collect (map f xs);

  traverseWithContext =
    ctxOf: f: xs:
    collect (map (x: withContext (ctxOf x) (f x)) xs);

  joinErrors =
    errs:
    let
      es = builtins.filter (e: e != null) errs;
      causes = lib.concatMap (e: if e.kind == "join" && e ? causes then e.causes else [ e ]) es;
    in
    if causes == [ ] then
      ok null
    else
      err {
        kind = "join";
        message = "${toString (builtins.length causes)} error(s)";
        inherit causes;
      };

  partition = rs: {
    values = map (r: r.value) (builtins.filter (r: r.ok) rs);
    errors = map (r: r.error) (builtins.filter (r: !r.ok) rs);
  };

  format =
    e:
    let
      fmt = v: if builtins.isString v || builtins.isPath v then toString v else builtins.toJSON v;
      ctx = lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${fmt v}") (e.context or { }));
      head =
        "error[${e.kind or "error"}]: ${e.message or "unknown"}" + (if ctx == "" then "" else " (${ctx})");
      causes = map (c: "\n  - ${format c}") (e.causes or [ ]);
    in
    head + lib.concatStrings causes;

  unwrap = r: if r.ok then r.value else throw (format r.error);
  unwrapOr = d: r: if r.ok then r.value else d;
  expect = msg: r: if r.ok then r.value else throw "${msg}: ${format r.error}";

  tryCatch =
    kind: thunk:
    let
      r = builtins.tryEval (builtins.deepSeq thunk thunk);
    in
    if r.success then
      ok r.value
    else
      err {
        inherit kind;
        message = "evaluation failed (details not capturable)";
      };
in
{
  inherit
    ok
    err
    isResult
    isOk
    isErr
    is
    mapOk
    mapError
    andThen
    withContext
    collect
    sequence
    traverse
    traverseWithContext
    joinErrors
    partition
    format
    unwrap
    unwrapOr
    expect
    tryCatch
    ;
}
