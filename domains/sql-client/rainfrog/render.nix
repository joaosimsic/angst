{
  checkHelpers,
}:

let
  inherit (checkHelpers) requireInfix;

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

  # DB connections are now managed at runtime via `angst db` (vault-encrypted
  # `secrets/db/<scope>.tar.age` → `~/.secrets/db/...`). The Nix render only emits
  # the static [settings] section; [db] is appended by the activation sync.
  configText = settingsText;
in
[
  {
    path = "domains/sql-client/rainfrog/config/rainfrog_config.toml";
    text = configText;
    checks = [
      (requireInfix settingsText "[settings]" "rainfrog config should include a [settings] section")
    ];
  }
]
