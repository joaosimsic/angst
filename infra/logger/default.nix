let
  strings = import ../lib/strings.nix;
  codesModule = import ../contracts/codes.nix;
  levelsModule = import ../contracts/levels.nix;
  secretRefModule = import ../contracts/secret-ref/default.nix;

  renderDiagnosticLine =
    diagnostic:
    let
      packages =
        if (diagnostic.packages or [ ]) == [ ] then
          ""
        else
          " packages=" + builtins.concatStringsSep "," diagnostic.packages;
      dataText =
        if (diagnostic.data or { }) == { } then "" else " data=" + builtins.toJSON diagnostic.data;
      line = "${diagnostic.code} [${diagnostic.phase}] ${diagnostic.scope}/${diagnostic.host}${packages}: ${diagnostic.message}${dataText}";
    in
    line;

  renderEventLine =
    event:
    let
      data = builtins.toJSON (event.data or { });
      line = "ts=${event.ts} level=${event.level} code=${event.code} scope=${event.scope} host=${event.host} phase=${event.phase} message=${event.message} data=${data}";
    in
    line;

  checkNonEmptyString =
    field: value:
    if strings.isNonEmptyString value then
      value
    else
      throw "logger: `${field}` must be a non-empty string";

  checkPackages =
    packages:
    if builtins.isList packages && builtins.all (package: builtins.isString package) packages then
      packages
    else
      throw "logger: `packages` must be a list of strings";

  checkData = data: if builtins.isAttrs data then data else throw "logger: `data` must be an attrset";

  validateDiagnostic =
    {
      code,
      scope,
      host,
      packages,
      phase,
      message,
      data ? { },
      secrets ? [ ],
      secretFields ? secretRefModule.secretSlugs,
    }:
    let
      checkedCode = codesModule.checkLogCode code;
      checkedScope = checkNonEmptyString "scope" scope;
      checkedHost = checkNonEmptyString "host" host;
      checkedPackages = checkPackages packages;
      checkedPhase = checkNonEmptyString "phase" phase;
      validatedMessage = checkNonEmptyString "message" message;
      checkedData = secretRefModule.checkSecretRefsIn {
        data = checkData data;
        inherit secretFields;
      };
      checkedMessage = secretRefModule.checkNoKnownSecrets secrets validatedMessage (
        builtins.toJSON checkedData
      );
    in
    {
      code = checkedCode;
      scope = checkedScope;
      host = checkedHost;
      packages = checkedPackages;
      phase = checkedPhase;
      message = checkedMessage;
      data = checkedData;
    };

  validateEvent =
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
      secretFields ? secretRefModule.secretSlugs,
    }:
    let
      checkedTimestamp = checkNonEmptyString "ts" ts;
      checkedLevel = levelsModule.checkLogLevel level;
      checkedCode = codesModule.checkLogCode code;
      checkedScope = checkNonEmptyString "scope" scope;
      checkedHost = checkNonEmptyString "host" host;
      checkedPackages = checkPackages packages;
      checkedPhase = checkNonEmptyString "phase" phase;
      validatedMessage = checkNonEmptyString "message" message;
      checkedData = secretRefModule.checkSecretRefsIn {
        data = checkData data;
        inherit secretFields;
      };
      checkedMessage = secretRefModule.checkNoKnownSecrets secrets validatedMessage (
        builtins.toJSON checkedData
      );
    in
    {
      ts = checkedTimestamp;
      level = checkedLevel;
      code = checkedCode;
      scope = checkedScope;
      host = checkedHost;
      packages = checkedPackages;
      phase = checkedPhase;
      message = checkedMessage;
      data = checkedData;
    };

  renderers = {
    diagnostic = renderDiagnosticLine;
    event = renderEventLine;
  };

  renderKind =
    value:
    if !(builtins.isAttrs value) then
      null
    else if value ? ts && value ? level then
      "event"
    else if value ? code && value ? message then
      "diagnostic"
    else
      null;

  renderDiagnosticsLines =
    diagnostics: builtins.concatStringsSep "\n" (builtins.map renderDiagnosticLine diagnostics);
in
{
  inherit (codesModule)
    checkLogCode
    logCodePrefix
    logCodes
    ;
  inherit (levelsModule)
    checkLogLevel
    isLogLevel
    logLevels
    ;
  inherit (secretRefModule)
    SecretRef
    checkNoKnownSecrets
    hasSecretsDir
    ;
  inherit (secretRefModule)
    checkSecretRef
    checkSecretRefsIn
    checkSecretRefsOnly
    isKnownSecretRef
    isSecretRef
    ;
  inherit (secretRefModule)
    inventoryWarn
    isInventoryEmpty
    secretFiles
    secretInventory
    secretSlugs
    ;

  diagnostic =
    arguments:
    let
      validatedDiagnostic = validateDiagnostic arguments;
    in
    validatedDiagnostic;

  event =
    arguments:
    let
      validatedEvent = validateEvent arguments;
    in
    validatedEvent;

  renderDiagnostic = renderDiagnosticLine;

  renderEvent = renderEventLine;

  render =
    value:
    let
      kind = renderKind value;
    in
    if kind == null then
      throw "logger render: expected diagnostic or event"
    else
      renderers.${kind} value;

  renderDiagnostics = renderDiagnosticsLines;

  throwDiagnostics =
    diagnostics:
    if !(builtins.isList diagnostics) then
      throw "logger throwDiagnostics: expected a list of diagnostics"
    else if diagnostics == [ ] then
      null
    else
      let
        count = builtins.length diagnostics;
        renderedDiagnostics = renderDiagnosticsLines diagnostics;
        message = "angst diagnostics (${toString count}):\n" + renderedDiagnostics;
      in
      throw message;

  toJSONL =
    events:
    builtins.concatStringsSep "\n" (
      builtins.map (
        event:
        let
          encodedEvent = builtins.toJSON event;
        in
        encodedEvent
      ) events
    );
}
