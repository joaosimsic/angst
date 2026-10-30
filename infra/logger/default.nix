# infra/logger/default.nix — thin facade: shapes, render, throw only.
#
# Pure data only. No printing. No IO. No `builtins.trace`.
# Vocab lives in `infra/contracts/` and is re-exported here, never
# redefined. Generic checks plus the `Result` core live in
# `infra/lib/types.nix`, regex matchers in `infra/lib/match.nix`
# (transitive via contracts/types). Validation accumulates via `collect` and throws
# once via `unwrap` with tree-formatted errors; single-field failures read
# the same as before.
# Phase/state literals stay unvalidated strings here; Step 3 imports the
# single source from `workflow/phases.nix` (no redefinition).
# JSONL (`builtins.toJSON` of `event`) is canonical; `render*` is a human
# terminal view. Secret values never enter events; only `SecretRef`.
let
  types = import ../lib/types.nix;
  codesMod = import ../contracts/codes.nix;
  levelsMod = import ../contracts/levels.nix;
  secretRefMod = import ../contracts/secret-ref.nix;

  renderDiagnosticFn =
    d:
    let
      pkgs =
        if (d.packages or [ ]) == [ ] then "" else " packages=" + builtins.concatStringsSep "," d.packages;
      dataStr = if (d.data or { }) == { } then "" else " data=" + builtins.toJSON d.data;
    in
    "${d.code} [${d.phase}] ${d.scope}/${d.host}${pkgs}: ${d.message}${dataStr}";

  renderEventFn = e: "${e.ts} ${e.level} ${e.code} [${e.phase}] ${e.scope}/${e.host}: ${e.message}";

  checkNonEmptyString =
    field: v:
    if types.isNonEmptyStr v then
      types.ok v
    else
      types.err {
        kind = "field";
        message = "logger: `${field}` must be a non-empty string";
        context = {
          field = field;
        };
      };

  checkPackages =
    packages:
    if builtins.isList packages && builtins.all builtins.isString packages then
      types.ok packages
    else
      types.err {
        kind = "field";
        message = "logger: `packages` must be a list of strings";
        context = {
          field = "packages";
        };
      };

  checkShape =
    ctx: checks: types.unwrap (types.mapOk (_: true) (types.withContext ctx (types.collect checks)));
in
{
  logCodes = codesMod.logCodes;
  logCodePrefix = codesMod.logCodePrefix;
  checkLogCode = codesMod.checkLogCode;
  assertLogCode = codesMod.assertLogCode;
  logLevels = levelsMod.logLevels;
  checkLogLevel = levelsMod.checkLogLevel;
  assertLogLevel = levelsMod.assertLogLevel;
  isLogLevel = levelsMod.isLogLevel;
  SecretRef = secretRefMod.SecretRef;
  checkSecretRef = secretRefMod.checkSecretRef;
  isSecretRef = secretRefMod.isSecretRef;
  isSecretKey = secretRefMod.isSecretKey;
  checkSecretRefsOnly = secretRefMod.checkSecretRefsOnly;
  assertSecretRefsOnly = secretRefMod.assertSecretRefsOnly;
  checkNoKnownSecrets = secretRefMod.checkNoKnownSecrets;
  assertNoKnownSecrets = secretRefMod.assertNoKnownSecrets;

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
      ctx = {
        inherit scope host phase;
      };
      _ = checkShape ctx [
        (codesMod.checkLogCode code)
        (checkNonEmptyString "scope" scope)
        (checkNonEmptyString "host" host)
        (checkPackages packages)
        (checkNonEmptyString "phase" phase)
        (checkNonEmptyString "message" message)
        (secretRefMod.checkSecretRefsOnly data)
        (secretRefMod.checkNoKnownSecrets secrets message (builtins.toJSON data))
      ];
    in
    assert _;
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
      ctx = {
        inherit scope host phase;
      };
      _ = checkShape ctx [
        (checkNonEmptyString "ts" ts)
        (levelsMod.checkLogLevel level)
        (codesMod.checkLogCode code)
        (checkNonEmptyString "scope" scope)
        (checkNonEmptyString "host" host)
        (checkPackages packages)
        (checkNonEmptyString "phase" phase)
        (checkNonEmptyString "message" message)
        (secretRefMod.checkSecretRefsOnly data)
        (secretRefMod.checkNoKnownSecrets secrets message (builtins.toJSON data))
      ];
    in
    assert _;
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

  renderDiagnostic = renderDiagnosticFn;

  renderEvent = renderEventFn;

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

  renderDiagnostics = diags: builtins.concatStringsSep "\n" (builtins.map renderDiagnosticFn diags);

  throwDiagnostics =
    diags:
    if !(builtins.isList diags) then
      throw "logger throwDiagnostics: expected a list of diagnostics"
    else if diags == [ ] then
      null
    else
      throw (
        "angst diagnostics (${toString (builtins.length diags)}):\n"
        + builtins.concatStringsSep "\n" (builtins.map renderDiagnosticFn diags)
      );

  toJSONL = events: builtins.concatStringsSep "\n" (builtins.map builtins.toJSON events);
}
