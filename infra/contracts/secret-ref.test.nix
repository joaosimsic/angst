let
  mod = import ./secret-ref.nix;
  types = import ../lib/types.nix;
  logger = import ../logger/default.nix;

  msgBadRef = "SecretRef: `ref` must be a non-empty string";
  msgUnknown = "SecretRef: unknown `ref`, no such slug under secrets/";
  msgField = "secret field must be `SecretRef { ref }`, never a plain string";
  msgMisplaced = "SecretRef misplaced: allowed only under secret fields";
  msgUnsupported = "SecretRef edge rejected: unsupported value type";
  msgLeak = "plain secret value present in message/data; wrap as `SecretRef` instead";

  assertOk =
    name: r: if types.isOk r then true else throw "FAIL ${name}: expected ok, got ${builtins.toJSON r}";

  assertErrMsg =
    name: expected: path: r:
    let
      actualMsg = if types.isErr r then r.error.message else "<not-err>";
      actualPath = if types.isErr r then (r.error.context.path or null) else "<not-err>";
    in
    if !types.isErr r then
      throw "FAIL ${name}: expected err `${expected}`, got ok ${builtins.toJSON r}"
    else if actualMsg != expected then
      throw "FAIL ${name}: wrong message, want `${expected}`, got `${actualMsg}` ${builtins.toJSON r}"
    else if path != null && actualPath != path then
      throw "FAIL ${name}: wrong path, want `${path}`, got `${builtins.toJSON actualPath}` ${builtins.toJSON r}"
    else
      true;

  assertTrue = name: cond: if cond then true else throw "FAIL ${name}: expected true";
  assertFalse = name: cond: if !cond then true else throw "FAIL ${name}: expected false";

  assertThrow =
    name: expr:
    let
      out = builtins.tryEval expr;
    in
    if out.success then
      throw "FAIL ${name}: expected throw, got ${builtins.toJSON out.value}"
    else
      true;

  withFields = data: secretFields: mod.checkSecretRefsIn { inherit data secretFields; };

  tests = [
    # inventory comes from secrets/, never regex
    (assertTrue "inv-opencode" (builtins.elem "opencode-go-key" mod.secretSlugs))
    (assertTrue "inv-cursor" (builtins.elem "cursor-api-key" mod.secretSlugs))
    (assertTrue "inv-example" (builtins.elem "example" mod.secretSlugs))
    (assertTrue "inv-files" (mod.secretFiles != [ ]))

    # inventory stays soft: Result, caller handles missing vs empty
    (assertTrue "inv-has-dir" (mod.hasSecretsDir == true))
    (assertOk "inv-result-ok" (types.mapOk (_: true) mod.inventoryResult))
    (assertTrue "inv-result-nonempty" (mod.inventoryResult.value != [ ]))
    (assertOk "inv-check-ok" mod.checkInventory)
    (assertFalse "inv-not-empty" mod.isInventoryEmpty)
    (assertTrue "inv-warn-null" (mod.inventoryWarn == null))
    (assertTrue "logger-inv-passthrough" (logger.inventoryResult.value == mod.inventoryResult.value))
    (assertOk "logger-check-ok" logger.checkInventory)
    (assertTrue "logger-warn-null" (logger.inventoryWarn == null))

    # checkSecretRef resolves against inventory
    (assertOk "ref-accept" (mod.checkSecretRef "opencode-go-key"))
    (assertErrMsg "ref-empty" msgBadRef null (mod.checkSecretRef ""))
    (assertErrMsg "ref-null" msgBadRef null (mod.checkSecretRef null))
    (assertErrMsg "ref-int" msgBadRef null (mod.checkSecretRef 123))
    (assertErrMsg "ref-unknown" msgUnknown null (mod.checkSecretRef "nope"))

    # isSecretRef is shape only, no inventory
    (assertTrue "isRef-valid" (mod.isSecretRef { ref = "x"; }))
    (assertFalse "isRef-empty" (mod.isSecretRef { ref = ""; }))
    (assertFalse "isRef-int" (mod.isSecretRef { ref = 123; }))
    (assertFalse "isRef-extra" (
      mod.isSecretRef {
        ref = "x";
        extra = 1;
      }
    ))
    (assertFalse "isRef-empty-attrs" (mod.isSecretRef { }))
    (assertFalse "isRef-string" (mod.isSecretRef "x"))
    (assertFalse "isRef-null" (mod.isSecretRef null))

    # isKnownSecretRef is inventory membership, exact, no guessing
    (assertTrue "known-opencode" (mod.isKnownSecretRef "opencode-go-key"))
    (assertTrue "known-cursor" (mod.isKnownSecretRef "cursor-api-key"))
    (assertTrue "known-example" (mod.isKnownSecretRef "example"))
    (assertTrue "known-ssh" (mod.isKnownSecretRef "personal.ed25519"))
    (assertFalse "known-empty" (mod.isKnownSecretRef ""))
    (assertFalse "known-nope" (mod.isKnownSecretRef "nope"))
    (assertFalse "known-int" (mod.isKnownSecretRef 123))
    (assertFalse "known-password" (mod.isKnownSecretRef "password"))
    (assertFalse "known-apiKey" (mod.isKnownSecretRef "apiKey"))
    (assertFalse "known-token" (mod.isKnownSecretRef "token"))
    (assertFalse "known-authToken" (mod.isKnownSecretRef "authToken"))
    (assertFalse "known-mySecret" (mod.isKnownSecretRef "mySecret"))
    (assertFalse "known-case" (mod.isKnownSecretRef "Opencode-Go-Key"))
    (assertFalse "known-foo" (mod.isKnownSecretRef "foo"))
    (assertFalse "known-host" (mod.isKnownSecretRef "host"))
    (assertFalse "known-author" (mod.isKnownSecretRef "author"))

    # refsOnly accepts
    (assertOk "ok-empty" (mod.checkSecretRefsOnly { }))
    (assertOk "ok-scalars" (
      mod.checkSecretRefsOnly {
        a = 1;
        s = "plain";
        n = null;
        b = true;
        f = 1.5;
      }
    ))
    (assertOk "ok-nested-plain" (
      mod.checkSecretRefsOnly {
        nested = {
          foo = "bar";
        };
      }
    ))
    (assertOk "ok-list" (
      mod.checkSecretRefsOnly {
        list = [
          1
          "a"
          null
        ];
      }
    ))
    (assertOk "ok-slug-field" (
      mod.checkSecretRefsOnly {
        opencode-go-key = {
          ref = "opencode-go-key";
        };
      }
    ))
    (assertOk "ok-nested-slug" (
      mod.checkSecretRefsOnly {
        db = {
          cursor-api-key = {
            ref = "cursor-api-key";
          };
        };
      }
    ))
    (assertOk "ok-list-of-ref-attrs" (
      mod.checkSecretRefsOnly {
        items = [
          {
            opencode-go-key = {
              ref = "opencode-go-key";
            };
          }
        ];
      }
    ))
    (assertOk "ok-declared" (withFields { password = { ref = "opencode-go-key"; }; } [ "password" ]))
    (assertOk "ok-declared-path" (
      withFields
        {
          db = {
            password = {
              ref = "example";
            };
          };
        }
        [ "data.db.password" ]
    ))
    (assertOk "ok-plain-undeclared" (mod.checkSecretRefsOnly { password = "plain"; }))

    # refsOnly rejects plain under declared secret fields
    (assertErrMsg "rej-plain" msgField "data.password" (
      withFields { password = "plain"; } [ "password" ]
    ))
    (assertErrMsg "rej-nested-plain" msgField "data.db.password" (
      withFields
        {
          db = {
            password = "plain";
          };
        }
        [ "data.db.password" ]
    ))
    (assertErrMsg "rej-list-under-secret" msgField "data.tokens" (
      withFields { tokens = [ "a" ]; } [ "tokens" ]
    ))
    (assertErrMsg "rej-unknown-ref" msgUnknown "data.password" (
      withFields { password = { ref = "nope"; }; } [ "password" ]
    ))

    # strict: bare ref only under secret fields
    (assertErrMsg "rej-misplaced" msgMisplaced "data.foo" (
      mod.checkSecretRefsOnly {
        foo = {
          ref = "opencode-go-key";
        };
      }
    ))
    (assertErrMsg "rej-misplaced-nested" msgMisplaced "data.a.foo" (
      mod.checkSecretRefsOnly {
        a = {
          foo = {
            ref = "opencode-go-key";
          };
        };
      }
    ))
    (assertErrMsg "rej-empty-bare" msgBadRef "data.foo" (
      mod.checkSecretRefsOnly {
        foo = {
          ref = "";
        };
      }
    ))
    (assertErrMsg "rej-empty-secret" msgBadRef "data.password" (
      withFields { password = { ref = ""; }; } [ "password" ]
    ))
    (assertErrMsg "rej-nonstr-secret" msgBadRef "data.password" (
      withFields { password = { ref = 123; }; } [ "password" ]
    ))

    # unsupported types
    (assertErrMsg "rej-fn-top" msgUnsupported "data" (mod.checkSecretRefsOnly (x: x)))
    (assertErrMsg "rej-fn-nested" msgUnsupported "data.foo" (mod.checkSecretRefsOnly { foo = x: x; }))

    # noKnownSecrets
    (assertOk "leak-clean" (mod.checkNoKnownSecrets [ "hunter2" ] "hello" "{\"a\":1}"))
    (assertOk "leak-empty-secrets" (mod.checkNoKnownSecrets [ ] "hello" "{}"))
    (assertErrMsg "leak-message" msgLeak null (
      mod.checkNoKnownSecrets [ "hunter2" ] "has hunter2 here" "{}"
    ))
    (assertErrMsg "leak-data" msgLeak null (
      mod.checkNoKnownSecrets [ "hunter2" ] "hi" "{\"k\":\"hunter2\"}"
    ))
    (assertErrMsg "leak-bad-secrets" "checkNoKnownSecrets: `secrets` must be a list" null (
      mod.checkNoKnownSecrets "nope" "hi" "{}"
    ))
    (assertErrMsg "leak-bad-inputs" "checkNoKnownSecrets: `message` and `dataJson` must be strings" null
      (mod.checkNoKnownSecrets [ ] null "{}")
    )

    # assert wrappers throw on bad, pass on good
    (assertThrow "assert-refs-throw" (
      mod.assertSecretRefsIn {
        data = {
          password = "plain";
        };
        secretFields = [ "password" ];
      }
    ))
    (assertThrow "assert-leak-throw" (mod.assertNoKnownSecrets [ "s3cr3t" ] "leak s3cr3t" "{}"))
    (assertTrue "assert-refs-ok" (
      mod.assertSecretRefsOnly {
        opencode-go-key = {
          ref = "opencode-go-key";
        };
      }
    ))
    (assertTrue "assert-leak-ok" (mod.assertNoKnownSecrets [ "s3cr3t" ] "clean" "{}"))

    # logger end-to-end via diagnostic/event
    (assertThrow "log-diag-plain" (
      logger.diagnostic {
        code = "SEC001";
        scope = "s";
        host = "h";
        packages = [ ];
        phase = "validate";
        message = "hi";
        secretFields = [ "password" ];
        data = {
          password = "plain";
        };
      }
    ))
    (assertThrow "log-diag-unknown" (
      logger.diagnostic {
        code = "SEC001";
        scope = "s";
        host = "h";
        packages = [ ];
        phase = "validate";
        message = "hi";
        secretFields = [ "password" ];
        data = {
          password = {
            ref = "nope";
          };
        };
      }
    ))
    (assertThrow "log-diag-misplaced" (
      logger.diagnostic {
        code = "SEC001";
        scope = "s";
        host = "h";
        packages = [ ];
        phase = "validate";
        message = "hi";
        data = {
          foo = {
            ref = "opencode-go-key";
          };
        };
      }
    ))
    (assertThrow "log-event-leak" (
      logger.event {
        ts = "t";
        level = "info";
        code = "SEC001";
        scope = "s";
        host = "h";
        packages = [ ];
        phase = "validate";
        message = "has hunter2";
        data = { };
        secrets = [ "hunter2" ];
      }
    ))
    # hard edges pass when inventory present, even with empty data
    (assertTrue "log-diag-ok-empty" (
      (logger.diagnostic {
        code = "SEC001";
        scope = "s";
        host = "h";
        packages = [ ];
        phase = "validate";
        message = "hi";
        data = { };
      }).message
      == "hi"
    ))
    (assertTrue "log-event-ok-empty" (
      (logger.event {
        ts = "t";
        level = "info";
        code = "SEC001";
        scope = "s";
        host = "h";
        packages = [ ];
        phase = "validate";
        message = "hi";
        data = { };
      }).message
      == "hi"
    ))
  ];
in
assert builtins.all (x: x) tests;
true
