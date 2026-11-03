let
  strings = import ../lib/strings.nix;
  error = import ../lib/error.nix;
  codesModule = import ../contracts/codes.nix;
  levelsModule = import ../contracts/levels.nix;
  secretRefModule = import ../contracts/secret-ref/default.nix;
  phasesModule = import ../../workflow/phases.nix;

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

  throwField =
    field: message:
    error.throwError {
      kind = "field";
      inherit message;
      context = { inherit field; };
    };

  checkNonEmptyString =
    field: value:
    if strings.isNonEmptyString value then
      value
    else
      throwField field "logger: `${field}` must be a non-empty string";

  checkPackages =
    packages:
    if builtins.isList packages && builtins.all (package: builtins.isString package) packages then
      packages
    else
      throwField "packages" "logger: `packages` must be a list of strings";

  checkPhase =
    phase:
    if builtins.elem phase phasesModule.phases then
      phase
    else
      error.throwError {
        kind = "field";
        message = "logger: unknown `phase`";
        context = {
          inherit phase;
          expected = phasesModule.phases;
        };
      };

  checkData =
    data: if builtins.isAttrs data then data else throwField "data" "logger: `data` must be an attrset";

  validateFields =
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
      checkedPhase = checkPhase phase;
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
    diagnostics: builtins.concatStringsSep "\n" (map renderDiagnosticLine diagnostics);
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
  inherit (phasesModule)
    phases
    states
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
      fields = validateFields arguments;
    in
    {
      inherit (fields)
        code
        data
        host
        message
        packages
        phase
        scope
        ;
    };

  event =
    arguments:
    let
      checkedTimestamp = checkNonEmptyString "ts" arguments.ts;
      checkedLevel = levelsModule.checkLogLevel arguments.level;
      fields = validateFields (
        removeAttrs arguments [
          "ts"
          "level"
        ]
      );
    in
    {
      ts = checkedTimestamp;
      level = checkedLevel;
      inherit (fields)
        code
        data
        host
        message
        packages
        phase
        scope
        ;
    };

  renderDiagnostic = renderDiagnosticLine;

  renderEvent = renderEventLine;

  render =
    value:
    let
      kind = renderKind value;
    in
    if kind == null then
      throwField "value" "logger render: expected diagnostic or event"
    else
      renderers.${kind} value;

  renderDiagnostics = renderDiagnosticsLines;

  throwDiagnostics =
    diagnostics:
    if !(builtins.isList diagnostics) then
      throwField "diagnostics" "logger throwDiagnostics: expected a list of diagnostics"
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
      map (
        event:
        let
          encodedEvent = builtins.toJSON event;
        in
        encodedEvent
      ) events
    );
}
