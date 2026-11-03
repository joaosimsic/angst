let
  logger = import ./default.nix;
  phasesModule = import ../../workflow/phases.nix;

  assertTrue = name: condition: if condition then true else throw "FAIL ${name}: expected true";

  assertFalse = name: condition: if !condition then true else throw "FAIL ${name}: expected false";

  assertThrow =
    name: expression:
    let
      outcome = builtins.tryEval (builtins.deepSeq expression expression);
    in
    if outcome.success then throw "FAIL ${name}: expected throw" else true;

  diagnostic = {
    code = "SEC001";
    scope = "secrets";
    host = "nixos";
    packages = [ ];
    phase = "validate";
    message = "message";
    data = { };
  };

  event = diagnostic // {
    ts = "2026-11-03T12:00:00Z";
    level = "info";
  };

  tests = [
    (assertTrue "code-known" (logger.checkLogCode "SEC001" == "SEC001"))
    (assertTrue "code-prefix" (logger.logCodePrefix "DESK042" == "DESK"))
    (assertTrue "code-prefix-null" (logger.logCodePrefix null == null))
    (assertTrue "code-prefix-number" (logger.logCodePrefix 1 == null))
    (assertThrow "code-unknown" (logger.checkLogCode "NOPE001"))
    (assertThrow "code-lowercase" (logger.checkLogCode "sec001"))
    (assertThrow "code-malformed" (logger.checkLogCode "SEC"))
    (assertThrow "code-null" (logger.checkLogCode null))

    (assertTrue "level-known" (logger.checkLogLevel "info" == "info"))
    (assertTrue "level-is-known" (logger.isLogLevel "warn"))
    (assertFalse "level-uppercase" (logger.isLogLevel "INFO"))
    (assertThrow "level-unknown" (logger.checkLogLevel "INFO"))
    (assertThrow "level-null" (logger.checkLogLevel null))

    (assertTrue "phases-reexport" (logger.phases == phasesModule.phases))
    (assertTrue "states-reexport" (logger.states == phasesModule.states))
    (assertTrue "phase-known" (
      builtins.all (
        phase: (logger.diagnostic (diagnostic // { inherit phase; })).phase == phase
      ) phasesModule.phases
    ))
    (assertThrow "diagnostic-unknown-phase" (logger.diagnostic (diagnostic // { phase = "deploy"; })))
    (assertThrow "event-unknown-phase" (logger.event (event // { phase = "deploy"; })))

    (assertTrue "diagnostic-shape" (
      builtins.attrNames (logger.diagnostic diagnostic) == [
        "code"
        "data"
        "host"
        "message"
        "packages"
        "phase"
        "scope"
      ]
    ))
    (assertTrue "event-shape" (
      builtins.attrNames (logger.event event) == [
        "code"
        "data"
        "host"
        "level"
        "message"
        "packages"
        "phase"
        "scope"
        "ts"
      ]
    ))
    (assertTrue "diagnostic-values" (
      logger.diagnostic diagnostic == {
        code = "SEC001";
        data = { };
        host = "nixos";
        message = "message";
        packages = [ ];
        phase = "validate";
        scope = "secrets";
      }
    ))

    (assertThrow "diagnostic-empty-scope" (logger.diagnostic (diagnostic // { scope = ""; })))
    (assertThrow "diagnostic-null-host" (logger.diagnostic (diagnostic // { host = null; })))
    (assertThrow "diagnostic-packages-string" (logger.diagnostic (diagnostic // { packages = "pkg"; })))
    (assertThrow "diagnostic-packages-item" (logger.diagnostic (diagnostic // { packages = [ 1 ]; })))
    (assertThrow "diagnostic-data-list" (logger.diagnostic (diagnostic // { data = [ ]; })))
    (assertThrow "diagnostic-empty-message" (logger.diagnostic (diagnostic // { message = ""; })))
    (assertThrow "diagnostic-empty-phase" (logger.diagnostic (diagnostic // { phase = ""; })))
    (assertThrow "diagnostic-plain-secret" (
      logger.diagnostic (
        diagnostic
        // {
          data = {
            password = "plain";
          };
          secretFields = [ "password" ];
        }
      )
    ))
    (assertThrow "diagnostic-unknown-ref" (
      logger.diagnostic (
        diagnostic
        // {
          data = {
            password = {
              ref = "nope";
            };
          };
          secretFields = [ "password" ];
        }
      )
    ))
    (assertThrow "diagnostic-misplaced-ref" (
      logger.diagnostic (
        diagnostic
        // {
          data = {
            foo = {
              ref = "SEC001";
            };
          };
        }
      )
    ))
    (assertThrow "diagnostic-leak" (
      logger.diagnostic (
        diagnostic
        // {
          message = "contains hunter2";
          secrets = [ "hunter2" ];
        }
      )
    ))

    (assertThrow "event-empty-ts" (logger.event (event // { ts = ""; })))
    (assertThrow "event-unknown-level" (logger.event (event // { level = "INFO"; })))

    (assertTrue "render-diagnostic" (logger.renderDiagnostic (logger.diagnostic diagnostic) != ""))
    (assertTrue "render-event" (logger.renderEvent (logger.event event) != ""))
    (assertTrue "render-dispatch" (
      logger.render (logger.event event) == logger.renderEvent (logger.event event)
    ))
    (assertThrow "render-invalid" (logger.render "nope"))

    (assertTrue "jsonl-single" (
      logger.toJSONL [ (logger.event event) ] == builtins.toJSON (logger.event event)
    ))
    (assertTrue "throw-diagnostics-empty" (logger.throwDiagnostics [ ] == null))
    (assertThrow "throw-diagnostics-list" (logger.throwDiagnostics [ (logger.diagnostic diagnostic) ]))
    (assertThrow "throw-diagnostics-invalid" (logger.throwDiagnostics "nope"))
  ];
in
if builtins.all (test: test) tests then true else throw "FAIL: logger tests"
