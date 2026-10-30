let
  match = import ./match.nix;

  ok = value: {
    _result = true;
    ok = true;
    inherit value;
  };

  normalizeError =
    e:
    if builtins.isString e then
      {
        kind = "error";
        message = e;
        context = { };
        causes = [ ];
      }
    else if builtins.isAttrs e then
      {
        kind = e.kind or "error";
        message = e.message or (builtins.toJSON e);
        context = e.context or { };
        causes = e.causes or [ ];
      }
    else
      {
        kind = "error";
        message = builtins.toJSON e;
        context = { };
        causes = [ ];
      };

  err = e: {
    _result = true;
    ok = false;
    error = normalizeError e;
  };

  isResult = v: builtins.isAttrs v && (v._result or false) == true;

  isOk = r: isResult r && r.ok == true;

  isErr = r: isResult r && r.ok == false;

  check = cond: e: if cond then ok true else err e;

  mapOk =
    f: r:
    if !(isResult r) then
      throw "mapOk: expected Result, got ${builtins.typeOf r}"
    else if r.ok then
      ok (f r.value)
    else
      r;

  andThen =
    f: r:
    if !(isResult r) then
      throw "andThen: expected Result, got ${builtins.typeOf r}"
    else if r.ok then
      let
        out = f r.value;
      in
      if !(isResult out) then throw "andThen: function must return a Result" else out
    else
      r;

  withContext =
    ctx: r:
    if !(isResult r) then
      throw "withContext: expected Result, got ${builtins.typeOf r}"
    else if r.ok then
      r
    else
      r
      // {
        error = r.error // {
          context = ctx // r.error.context;
        };
      };

  collect =
    results:
    if !(builtins.isList results) then
      throw "collect: expected list of Results, got ${builtins.typeOf results}"
    else
      let
        bad = builtins.filter isErr results;
      in
      if bad == [ ] then
        ok (map (r: r.value) results)
      else if builtins.length bad == 1 then
        builtins.head bad
      else
        err {
          kind = "join";
          message = "${toString (builtins.length bad)} error(s)";
          causes = map (r: r.error) bad;
        };

  format =
    let
      showAttrs =
        ctx:
        let
          names = builtins.attrNames ctx;
        in
        if names == [ ] then
          ""
        else
          " (" + builtins.concatStringsSep " " (map (k: "${k}=${builtins.toJSON ctx.${k}}") names) + ")";
      show =
        depth: e:
        let
          pad = builtins.concatStringsSep "" (builtins.genList (_: "  ") depth);
        in
        pad
        + "error[${e.kind or "error"}]: ${e.message or (builtins.toJSON e)}${showAttrs (e.context or { })}"
        + (
          if (e.causes or [ ]) == [ ] then
            ""
          else
            "\n" + builtins.concatStringsSep "\n" (map (show (depth + 1)) (e.causes or [ ]))
        );
    in
    r:
    if isErr r then
      show 0 r.error
    else if builtins.isAttrs r && r ? message then
      show 0 (normalizeError r)
    else
      throw "format: expected Err result or error attrset";

  unwrap =
    r:
    if isOk r then
      r.value
    else if isErr r then
      throw (format r)
    else
      throw "unwrap: expected Result, got ${builtins.typeOf r}";
in
{
  inherit
    ok
    err
    normalizeError
    isResult
    isOk
    isErr
    check
    mapOk
    andThen
    withContext
    collect
    format
    unwrap
    ;

  isNonEmptyStr = v: builtins.isString v && v != "";

  isRelPath =
    v:
    if !(builtins.isString v) || v == "" then
      false
    else
      let
        parts = builtins.split "/" v;
        segs = builtins.filter (x: !(builtins.isList x)) parts;
      in
      builtins.substring 0 1 v != "/"
      && builtins.substring 0 1 v != "~"
      && !(builtins.elem "" segs)
      && !(builtins.elem "." segs)
      && !(builtins.elem ".." segs)
      && builtins.all (s: builtins.substring 0 1 s != "~") segs;

  isBasename =
    v:
    builtins.isString v
    && v != ""
    && v != "."
    && v != ".."
    && builtins.substring 0 1 v != "~"
    && !(match.hasSlash v);
}
