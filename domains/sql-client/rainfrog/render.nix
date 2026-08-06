{
  lib,
  checkHelpers,
  db,
  ...
}:

let
  inherit (checkHelpers) requireInfix require;

  conns = db.connections or { };

  rainfrogDrivers = {
    postgres = "postgres";
    mysql = "mysql";
    sqlite = "sqlite";
    oracle = "oracle";
    duckdb = "duckdb";
  };

  settingsText = ''
    [settings]
    mouse_mode = true
    data_compact_columns = true
    data_row_spacer = false
    autocomplete_enabled = true
    autocomplete_debounce_ms = 100
    autocomplete_trigger_len = 1
    autopairs_enabled = true
  '';

  mkInlineEntry =
    name: conn:
    let
      driver =
        rainfrogDrivers.${conn.type}
          or (throw "rainfrog: unsupported db type '${conn.type}' for connection '${name}' (supported: ${builtins.concatStringsSep ", " (builtins.attrNames rainfrogDrivers)})");
      defaultFlag = lib.optionalString (conn.default or false) ", default = true";
    in
    if conn.type == "sqlite" then
      ''${name} = { connection_string = "sqlite://${conn.path}", driver = "sqlite"${defaultFlag} }''
    else
      ''${name} = { host = "${conn.host}", port = ${toString (conn.port or 5432)}, database = "${conn.database}", username = "${conn.username}", driver = "${driver}"${defaultFlag} }'';

  dbText =
    if conns == { } then
      ""
    else
      "\n[db]\n" + lib.concatStringsSep "\n" (lib.mapAttrsToList mkInlineEntry conns) + "\n";

  configText = settingsText + dbText;

  connChecks = lib.mapAttrsToList (
    name: _: (requireInfix configText "${name} = {" "rainfrog config should include connection ${name}")
  ) conns;
in
[
  {
    path = "domains/sql-client/rainfrog/config/rainfrog_config.toml";
    text = configText;
    checks = [
      (requireInfix settingsText "[settings]" "rainfrog config should include a [settings] section")
    ]
    ++ connChecks
    ++ [
      (require (
        db.connections or { } == { } || lib.all (conn: conn ? type) (lib.attrValues conns)
      ) "rainfrog: every db connection must define a 'type'")
    ];
  }
]
