let
  secretRefModule = import ./default.nix;
  inventoryModule = import ./inventory.nix;
  validationModule = import ./validate.nix;
  leakModule = import ./leak.nix;
  logger = import ../../logger/default.nix;

  assertTrue = name: condition: if condition then true else throw "FAIL ${name}: expected true";

  assertFalse = name: condition: if !condition then true else throw "FAIL ${name}: expected false";

  assertThrow =
    name: expression:
    let
      outcome = builtins.tryEval expression;
    in
    if outcome.success then
      throw "FAIL ${name}: expected throw, got ${builtins.toJSON outcome.value}"
    else
      true;

  withFields = data: secretFields: secretRefModule.checkSecretRefsIn { inherit data secretFields; };

  entryAt = directory: basename: {
    inherit basename;
    fileType = "regular";
    relativePath = if directory == "" then basename else directory + "/" + basename;
  };

  makeFixture =
    {
      hasDir ? true,
      entries ? [ ],
    }:
    let
      inventory = inventoryModule.mkSecretInventory { inherit hasDir entries; };
    in
    inventory
    // (validationModule.mkSecretRefValidation inventory)
    // {
      inherit (leakModule) checkNoKnownSecrets;
    };

  tests = [
    (assertTrue "inv-opencode" (builtins.elem "opencode-go-key" secretRefModule.secretSlugs))
    (assertTrue "inv-cursor" (builtins.elem "cursor-api-key" secretRefModule.secretSlugs))
    (assertTrue "inv-example" (builtins.elem "example" secretRefModule.secretSlugs))
    (assertTrue "inv-files" (secretRefModule.secretFiles != [ ]))
    (assertTrue "inv-has-dir" secretRefModule.hasSecretsDir)
    (assertTrue "inv-not-empty" (!secretRefModule.isInventoryEmpty))
    (assertTrue "inv-warn-null" (secretRefModule.inventoryWarn == null))

    (
      let
        inventory = makeFixture { hasDir = false; };
      in
      assertThrow "fx-missing" inventory.secretSlugs
    )

    (
      let
        inventory = makeFixture { };
      in
      assertTrue "fx-empty-ok" (inventory.secretSlugs == [ ])
    )
    (
      let
        inventory = makeFixture { };
      in
      assertTrue "fx-empty-flag" inventory.isInventoryEmpty
    )
    (
      let
        inventory = makeFixture { };
      in
      assertTrue "fx-empty-warn" (
        inventory.inventoryWarn != null && inventory.inventoryWarn.code == "SEC002"
      )
    )
    (
      let
        inventory = makeFixture {
          entries = [
            (entryAt "" "README.md")
            {
              basename = "apps";
              fileType = "directory";
              relativePath = "apps";
            }
          ];
        };
      in
      assertTrue "fx-ignored" (inventory.secretSlugs == [ ])
    )

    (
      let
        inventory = makeFixture {
          entries = [
            (entryAt "apps/a" "alpha.placeholder")
            (entryAt "apps/b" "beta.age")
            (entryAt "passwd" "gamma.age.placeholder")
            (entryAt "ssh" "delta.pub")
            (entryAt "" "README.md")
          ];
        };
      in
      assertTrue "fx-suffix-slugs" (
        inventory.secretSlugs == [
          "alpha"
          "beta"
          "delta"
          "gamma"
        ]
      )
    )
    (
      let
        inventory = makeFixture {
          entries = [
            (entryAt "apps/a" "dup.age")
            (entryAt "apps/b" "dup.age")
          ];
        };
      in
      assertThrow "fx-duplicate" inventory.secretSlugs
    )
    (
      let
        inventory = makeFixture {
          entries = [
            (entryAt "apps/a" "pair.age")
            (entryAt "apps/a" "pair.pub")
          ];
        };
      in
      assertTrue "fx-pair" (inventory.secretSlugs == [ "pair" ])
    )
    (
      let
        inventory = makeFixture {
          entries = [
            (entryAt "apps/a" "mixed.placeholder")
            (entryAt "apps/a" "mixed.age")
          ];
        };
      in
      assertThrow "fx-placeholder-mixed" inventory.secretSlugs
    )
    (
      let
        inventory = makeFixture {
          entries = [
            (entryAt "apps/a" "split.age")
            (entryAt "apps/b" "split.pub")
          ];
        };
      in
      assertThrow "fx-cross-dir-pair" inventory.secretSlugs
    )
    (
      let
        inventory = makeFixture { entries = [ (entryAt "" "fixture.age") ]; };
      in
      assertTrue "fx-ref" (inventory.checkSecretRef "fixture" == { ref = "fixture"; })
    )
    (assertThrow "fx-ref-unknown" ((makeFixture { }).checkSecretRef "nope"))

    (assertTrue "ref-accept" (
      secretRefModule.checkSecretRef "opencode-go-key" == { ref = "opencode-go-key"; }
    ))
    (assertThrow "ref-empty" (secretRefModule.checkSecretRef ""))
    (assertThrow "ref-null" (secretRefModule.checkSecretRef null))
    (assertThrow "ref-int" (secretRefModule.checkSecretRef 123))
    (assertThrow "ref-unknown" (secretRefModule.checkSecretRef "nope"))

    (assertTrue "isRef-valid" (secretRefModule.isSecretRef { ref = "x"; }))
    (assertFalse "isRef-empty" (secretRefModule.isSecretRef { ref = ""; }))
    (assertFalse "isRef-int" (secretRefModule.isSecretRef { ref = 123; }))
    (assertFalse "isRef-extra" (
      secretRefModule.isSecretRef {
        ref = "x";
        extra = 1;
      }
    ))
    (assertFalse "isRef-empty-attrs" (secretRefModule.isSecretRef { }))
    (assertFalse "isRef-string" (secretRefModule.isSecretRef "x"))
    (assertFalse "isRef-null" (secretRefModule.isSecretRef null))

    (assertTrue "known-opencode" (secretRefModule.isKnownSecretRef "opencode-go-key"))
    (assertTrue "known-cursor" (secretRefModule.isKnownSecretRef "cursor-api-key"))
    (assertTrue "known-example" (secretRefModule.isKnownSecretRef "example"))
    (assertTrue "known-ssh" (secretRefModule.isKnownSecretRef "personal.ed25519"))
    (assertFalse "known-empty" (secretRefModule.isKnownSecretRef ""))
    (assertFalse "known-nope" (secretRefModule.isKnownSecretRef "nope"))
    (assertFalse "known-int" (secretRefModule.isKnownSecretRef 123))
    (assertFalse "known-password" (secretRefModule.isKnownSecretRef "password"))
    (assertFalse "known-apiKey" (secretRefModule.isKnownSecretRef "apiKey"))
    (assertFalse "known-token" (secretRefModule.isKnownSecretRef "token"))
    (assertFalse "known-authToken" (secretRefModule.isKnownSecretRef "authToken"))
    (assertFalse "known-mySecret" (secretRefModule.isKnownSecretRef "mySecret"))
    (assertFalse "known-case" (secretRefModule.isKnownSecretRef "Opencode-Go-Key"))
    (assertFalse "known-foo" (secretRefModule.isKnownSecretRef "foo"))
    (assertFalse "known-host" (secretRefModule.isKnownSecretRef "host"))
    (assertFalse "known-author" (secretRefModule.isKnownSecretRef "author"))

    (assertTrue "ok-empty" (secretRefModule.checkSecretRefsOnly { } == { }))
    (assertTrue "ok-scalars" (
      secretRefModule.checkSecretRefsOnly {
        a = 1;
        b = true;
        f = 1.5;
        n = null;
        s = "plain";
      } == {
        a = 1;
        b = true;
        f = 1.5;
        n = null;
        s = "plain";
      }
    ))
    (assertTrue "ok-nested-plain" (
      secretRefModule.checkSecretRefsOnly {
        nested = {
          foo = "bar";
        };
      } == {
        nested = {
          foo = "bar";
        };
      }
    ))
    (assertTrue "ok-list" (
      secretRefModule.checkSecretRefsOnly {
        list = [
          1
          "a"
          null
        ];
      } == {
        list = [
          1
          "a"
          null
        ];
      }
    ))
    (assertTrue "ok-slug-field" (
      secretRefModule.checkSecretRefsOnly {
        opencode-go-key = {
          ref = "opencode-go-key";
        };
      } == {
        opencode-go-key = {
          ref = "opencode-go-key";
        };
      }
    ))
    (assertTrue "ok-nested-slug" (
      secretRefModule.checkSecretRefsOnly {
        db = {
          cursor-api-key = {
            ref = "cursor-api-key";
          };
        };
      } == {
        db = {
          cursor-api-key = {
            ref = "cursor-api-key";
          };
        };
      }
    ))
    (assertTrue "ok-list-of-ref-attrs" (
      secretRefModule.checkSecretRefsOnly {
        items = [
          {
            opencode-go-key = {
              ref = "opencode-go-key";
            };
          }
        ];
      } == {
        items = [
          {
            opencode-go-key = {
              ref = "opencode-go-key";
            };
          }
        ];
      }
    ))
    (assertTrue "ok-declared" (
      withFields {
        password = {
          ref = "opencode-go-key";
        };
      } [ "password" ] == {
        password = {
          ref = "opencode-go-key";
        };
      }
    ))
    (assertTrue "ok-declared-path" (
      withFields {
        db = {
          password = {
            ref = "example";
          };
        };
      } [ "data.db.password" ] == {
        db = {
          password = {
            ref = "example";
          };
        };
      }
    ))
    (assertTrue "ok-plain-undeclared" (
      secretRefModule.checkSecretRefsOnly { password = "plain"; } == { password = "plain"; }
    ))

    (assertThrow "rej-plain" (withFields { password = "plain"; } [ "password" ]))
    (assertThrow "rej-nested-plain" (
      withFields {
        db = {
          password = "plain";
        };
      } [ "data.db.password" ]
    ))
    (assertThrow "rej-list-under-secret" (withFields { tokens = [ "a" ]; } [ "tokens" ]))
    (assertThrow "rej-unknown-ref" (
      withFields {
        password = {
          ref = "nope";
        };
      } [ "password" ]
    ))
    (assertThrow "rej-misplaced" (
      secretRefModule.checkSecretRefsOnly {
        foo = {
          ref = "opencode-go-key";
        };
      }
    ))
    (assertThrow "rej-misplaced-nested" (
      secretRefModule.checkSecretRefsOnly {
        a = {
          foo = {
            ref = "opencode-go-key";
          };
        };
      }
    ))
    (assertThrow "rej-empty-bare" (
      secretRefModule.checkSecretRefsOnly {
        foo = {
          ref = "";
        };
      }
    ))
    (assertThrow "rej-empty-secret" (
      withFields {
        password = {
          ref = "";
        };
      } [ "password" ]
    ))
    (assertThrow "rej-nonstr-secret" (
      withFields {
        password = {
          ref = 123;
        };
      } [ "password" ]
    ))
    (assertThrow "rej-fn-top" (secretRefModule.checkSecretRefsOnly (value: value)))
    (assertThrow "rej-fn-nested" (secretRefModule.checkSecretRefsOnly { foo = value: value; }))
    (assertThrow "rej-list-index" (
      (makeFixture { }).checkSecretRefsIn {
        data = {
          items = [
            1
            (value: value)
          ];
        };
        secretFields = [ ];
      }
    ))
    (assertThrow "rej-secret-fields" (
      (makeFixture { }).checkSecretRefsIn {
        data = { };
        secretFields = "password";
      }
    ))

    (assertTrue "leak-clean" (
      secretRefModule.checkNoKnownSecrets [ "hunter2" ] "hello" "{\"a\":1}" == "hello"
    ))
    (assertTrue "leak-empty-secrets" (secretRefModule.checkNoKnownSecrets [ ] "hello" "{}" == "hello"))
    (assertThrow "leak-message" (
      secretRefModule.checkNoKnownSecrets [ "hunter2" ] "has hunter2 here" "{}"
    ))
    (assertThrow "leak-data" (
      secretRefModule.checkNoKnownSecrets [ "hunter2" ] "hi" "{\"k\":\"hunter2\"}"
    ))
    (assertThrow "leak-json-escaped" (
      secretRefModule.checkNoKnownSecrets [ "a\"b\\c" ] "clean" (builtins.toJSON { k = "a\"b\\c"; })
    ))
    (assertThrow "leak-bad-elements" (secretRefModule.checkNoKnownSecrets [ "" ] "hi" "{}"))
    (assertThrow "leak-bad-secrets" (secretRefModule.checkNoKnownSecrets "nope" "hi" "{}"))
    (assertThrow "leak-bad-inputs" (secretRefModule.checkNoKnownSecrets [ ] null "{}"))

    (assertThrow "log-diag-plain" (
      builtins.deepSeq (logger.diagnostic {
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
      }) true
    ))
    (assertThrow "log-diag-unknown" (
      builtins.deepSeq (logger.diagnostic {
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
      }) true
    ))
    (assertThrow "log-diag-misplaced" (
      builtins.deepSeq (logger.diagnostic {
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
      }) true
    ))
    (assertThrow "log-event-leak" (
      builtins.deepSeq (logger.event {
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
      }) true
    ))
    (assertTrue "log-diag-ok-empty" (
      builtins.deepSeq (logger.diagnostic {
        code = "SEC001";
        scope = "s";
        host = "h";
        packages = [ ];
        phase = "validate";
        message = "hi";
        data = { };
      }) true
    ))
    (assertTrue "log-event-ok-empty" (
      builtins.deepSeq (logger.event {
        ts = "t";
        level = "info";
        code = "SEC001";
        scope = "s";
        host = "h";
        packages = [ ];
        phase = "validate";
        message = "hi";
        data = { };
      }) true
    ))
  ];
in
if builtins.all (test: test) tests then true else throw "FAIL: secret-ref tests"
