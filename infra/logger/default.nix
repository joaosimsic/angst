# infra/logger/default.nix — Step 2: Nix event schema, pure data only.
#
# Pure data only. No printing. No IO. No builtins.trace.
# JSONL (builtins.toJSON of `event`) is canonical; `render*` is a human
# terminal view only.
# Secret values never enter events; only `SecretRef` ({ ref } only).
# Phase/state literals stay unvalidated strings here; Step 3 imports the
# single source from `workflow/phases.nix` (no redefinition).
rec {
  codes = [
    "TGT"
    "PKG"
    "PROF"
    "DESK"
    "CTX"
    "SEC"
    "VM"
    "PROJ"
    "DEP"
    "ACT"
    "LOG"
    "ARCH"
  ];

  levels = [
    "error"
    "warn"
    "info"
    "step"
  ];

  # SecretRef constructor: exactly { ref }, nothing else.
  SecretRef =
    ref:
    if !(builtins.isString ref) || ref == "" then
      throw "SecretRef: `ref` must be a non-empty string"
    else
      { ref = ref; };

  isSecretRef =
    v:
    builtins.isAttrs v && builtins.attrNames v == [ "ref" ] && builtins.isString v.ref && v.ref != "";

  # Any attr name mentioning secrets must hold a SecretRef, never a plain string.
  isSecretKey =
    name:
    builtins.match ".*(secret|Secret|SECRET|token|Token|password|Password|passwd|private|Private|credential|Credential|apiKey|api_key|auth|Auth|decrypted|Decrypted).*" name
    != null;

  # Recursive edge guard: plain secret strings rejected, SecretRef required.
  assertSecretRefsOnly =
    let
      walk =
        path: v:
        if v == null || builtins.isBool v || builtins.isInt v || builtins.isFloat v then
          true
        else if builtins.isString v then
          true
        else if builtins.isList v then
          builtins.all (x: walk path x) v
        else if builtins.isAttrs v then
          if builtins.attrNames v == [ "ref" ] && builtins.isString (v.ref or null) then
            true
          else
            builtins.all (
              name:
              let
                child = v.${name};
                sub = path + "." + name;
              in
              if
                builtins.match ".*(secret|Secret|SECRET|token|Token|password|Password|passwd|private|Private|credential|Credential|apiKey|api_key|auth|Auth|decrypted|Decrypted).*" name
                != null
              then
                if
                  builtins.isAttrs child
                  && builtins.attrNames child == [ "ref" ]
                  && builtins.isString (child.ref or null)
                  && child.ref != ""
                then
                  true
                else
                  throw "SecretRef edge rejected at `${sub}`: secret field must be `SecretRef { ref }`, never a plain string"
              else
                walk sub child
            ) (builtins.attrNames v)
        else
          throw "SecretRef edge rejected: unsupported value type";
    in
    data: walk "data" data;

  # Known-value guard: caller-supplied secret strings must not appear in
  # message or data JSON. Eval never sees decrypted values, so default is [].
  assertNoKnownSecrets =
    secrets: message: dataJson:
    let
      contains =
        needle: haystack:
        builtins.isString needle
        && needle != ""
        && builtins.isString haystack
        && haystack != builtins.replaceStrings [ needle ] [ "" ] haystack;
      bad = builtins.filter (s: contains s message || contains s dataJson) secrets;
    in
    if bad != [ ] then
      throw "SecretRef edge rejected: plain secret value present in message/data; wrap as `SecretRef` instead"
    else
      true;

  codePrefix =
    code:
    let
      m = builtins.match "([A-Z]+)[0-9]+$" code;
    in
    if m == null then null else builtins.head m;

  assertCode =
    code:
    let
      prefix = builtins.match "([A-Z]+)[0-9]+$" code;
    in
    if !(builtins.isString code) || prefix == null then
      throw "logger: `code` must look like PREFIXNNN (e.g. DESK001), got `${builtins.toJSON code}`"
    else if
      !(builtins.elem (builtins.head prefix) [
        "TGT"
        "PKG"
        "PROF"
        "DESK"
        "CTX"
        "SEC"
        "VM"
        "PROJ"
        "DEP"
        "ACT"
        "LOG"
        "ARCH"
      ])
    then
      throw "logger: unknown code prefix `${builtins.head prefix}`; expected one of TGT PKG PROF DESK CTX SEC VM PROJ DEP ACT LOG ARCH"
    else
      true;

  assertPackages =
    packages:
    if !(builtins.isList packages) || !(builtins.all builtins.isString packages) then
      throw "logger: `packages` must be a list of strings"
    else
      true;

  assertNonEmptyString =
    name: v:
    if !(builtins.isString v) || v == "" then
      throw "logger: `${name}` must be a non-empty string"
    else
      true;

  # diagnostic: { code, scope, host, packages, phase, message, data }.
  # No ts, no level. Extra `secrets` arg is edge-only, never emitted.
  diagnostic =
    {
      code,
      scope,
      host,
      packages,
      phase,
      message,
      data ? { },
      secrets ? [ ],
    }:
    assert builtins.isAttrs data;
    let
      _code = assertCode code;
      _scope = assertNonEmptyString "scope" scope;
      _host = assertNonEmptyString "host" host;
      _pkgs = assertPackages packages;
      _phase = assertNonEmptyString "phase" phase;
      _msg = assertNonEmptyString "message" message;
      _edge = assertSecretRefsOnly data;
      _known = assertNoKnownSecrets secrets message (builtins.toJSON data);
    in
    assert _code && _scope && _host && _pkgs && _phase && _msg && _edge && _known;
    {
      inherit
        code
        scope
        host
        packages
        phase
        message
        data
        ;
    };

  # event: { ts, level, code, scope, host, packages, phase, message, data }.
  # Matches ## Logging JSON example keys exactly.
  event =
    {
      ts,
      level,
      code,
      scope,
      host,
      packages,
      phase,
      message,
      data ? { },
      secrets ? [ ],
    }:
    assert builtins.isAttrs data;
    let
      _ts = assertNonEmptyString "ts" ts;
      _level =
        if
          !(builtins.elem level [
            "error"
            "warn"
            "info"
            "step"
          ])
        then
          throw "logger: `level` must be one of error warn info step, got `${builtins.toJSON level}`"
        else
          true;
      _code = assertCode code;
      _scope = assertNonEmptyString "scope" scope;
      _host = assertNonEmptyString "host" host;
      _pkgs = assertPackages packages;
      _phase = assertNonEmptyString "phase" phase;
      _msg = assertNonEmptyString "message" message;
      _edge = assertSecretRefsOnly data;
      _known = assertNoKnownSecrets secrets message (builtins.toJSON data);
    in
    assert _ts && _level && _code && _scope && _host && _pkgs && _phase && _msg && _edge && _known;
    {
      inherit
        ts
        level
        code
        scope
        host
        packages
        phase
        message
        data
        ;
    };

  # Human terminal view. JSONL stays canonical via builtins.toJSON.
  renderDiagnostic =
    d:
    let
      pkgs =
        if (d.packages or [ ]) == [ ] then "" else " packages=" + builtins.concatStringsSep "," d.packages;
      dataStr = if (d.data or { }) == { } then "" else " data=" + builtins.toJSON d.data;
    in
    "${d.code} [${d.phase}] ${d.scope}/${d.host}${pkgs}: ${d.message}${dataStr}";

  renderEvent = e: "${e.ts} ${e.level} ${e.code} [${e.phase}] ${e.scope}/${e.host}: ${e.message}";

  render =
    v:
    if builtins.isAttrs v && v ? ts && v ? level then
      "ts=${v.ts} level=${v.level} code=${v.code} scope=${v.scope} host=${v.host} phase=${v.phase} message=${v.message} data=${
        builtins.toJSON (v.data or { })
      }"
    else if builtins.isAttrs v && v ? code && v ? message then
      "code=${v.code} scope=${v.scope or ""} host=${v.host or ""} phase=${v.phase or ""} message=${v.message} data=${
        builtins.toJSON (v.data or { })
      }"
    else
      throw "logger render: expected diagnostic or event";

  renderDiagnostics = diags: builtins.concatStringsSep "\n" (builtins.map renderDiagnostic diags);

  # Grouped collect-all, single throw. No warn mode, no allowlist flag.
  throwDiagnostics =
    diags:
    if !(builtins.isList diags) then
      throw "logger throwDiagnostics: expected a list of diagnostics"
    else if diags == [ ] then
      null
    else
      throw (
        "angst diagnostics (${toString (builtins.length diags)}):\n"
        + builtins.concatStringsSep "\n" (builtins.map renderDiagnostic diags)
      );

  # Canonical JSONL: one event per line.
  toJSONL = events: builtins.concatStringsSep "\n" (builtins.map builtins.toJSON events);
}
