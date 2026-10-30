let
  mod = import ./secret-ref.nix;
  types = import ../lib/types.nix;
  logger = import ../logger/default.nix;

  msgBadRef = "SecretRef: `ref` must be a non-empty string";
  msgField = "secret field must be `SecretRef { ref }`, never a plain string";
  msgMisplaced = "SecretRef misplaced: allowed only under secret keys";
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

  tests = [
    # checkSecretRef
    (assertOk "ref-accept" (mod.checkSecretRef "k1"))
    (assertErrMsg "ref-empty" msgBadRef null (mod.checkSecretRef ""))
    (assertErrMsg "ref-null" msgBadRef null (mod.checkSecretRef null))
    (assertErrMsg "ref-int" msgBadRef null (mod.checkSecretRef 123))

    # isSecretRef
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

    # isSecretKey sampling secretKeyPattern
    (assertTrue "key-password" (mod.isSecretKey "password"))
    (assertTrue "key-apiKey" (mod.isSecretKey "apiKey"))
    (assertTrue "key-token" (mod.isSecretKey "token"))
    (assertTrue "key-mySecret" (mod.isSecretKey "mySecret"))
    (assertTrue "key-authToken" (mod.isSecretKey "authToken"))
    (assertFalse "key-foo" (mod.isSecretKey "foo"))
    (assertFalse "key-host" (mod.isSecretKey "host"))

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
    (assertOk "ok-valid-ref" (
      mod.checkSecretRefsOnly {
        password = {
          ref = "k";
        };
      }
    ))
    (assertOk "ok-nested-ref" (
      mod.checkSecretRefsOnly {
        db = {
          password = {
            ref = "k";
          };
        };
      }
    ))
    (assertOk "ok-list-of-ref-attrs" (
      mod.checkSecretRefsOnly {
        items = [
          {
            password = {
              ref = "k";
            };
          }
        ];
      }
    ))

    # refsOnly rejects plain under secret keys
    (assertErrMsg "rej-plain" msgField "data.password" (
      mod.checkSecretRefsOnly { password = "plain"; }
    ))
    (assertErrMsg "rej-nested-plain" msgField "data.db.password" (
      mod.checkSecretRefsOnly {
        db = {
          password = "plain";
        };
      }
    ))
    (assertErrMsg "rej-list-under-secret" msgField "data.tokens" (
      mod.checkSecretRefsOnly { tokens = [ "a" ]; }
    ))

    # strict: bare ref only under secret keys
    (assertErrMsg "rej-misplaced" msgMisplaced "data.foo" (
      mod.checkSecretRefsOnly {
        foo = {
          ref = "x";
        };
      }
    ))
    (assertErrMsg "rej-misplaced-nested" msgMisplaced "data.a.foo" (
      mod.checkSecretRefsOnly {
        a = {
          foo = {
            ref = "x";
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
      mod.checkSecretRefsOnly {
        password = {
          ref = "";
        };
      }
    ))
    (assertErrMsg "rej-nonstr-secret" msgBadRef "data.password" (
      mod.checkSecretRefsOnly {
        password = {
          ref = 123;
        };
      }
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
    (assertThrow "assert-refs-throw" (mod.assertSecretRefsOnly { password = "plain"; }))
    (assertThrow "assert-leak-throw" (mod.assertNoKnownSecrets [ "s3cr3t" ] "leak s3cr3t" "{}"))
    (assertTrue "assert-refs-ok" (
      mod.assertSecretRefsOnly {
        password = {
          ref = "k";
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
        data = {
          password = "plain";
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
            ref = "x";
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
  ];
in
assert builtins.all (x: x) tests;
true
