{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;

  svelteBiomeConfig = pkgs.writeText "svelte-biome.json" ''
    {
      "$schema": "https://biomejs.dev/schemas/2.5.15/schema.json",
      "html": {
        "experimentalFullSupportEnabled": true
      },
      "formatter": {
        "enabled": true,
        "indentStyle": "space",
        "indentWidth": 2
      },
      "linter": {
        "enabled": true,
        "rules": {
          "recommended": true
        }
      },
      "overrides": [
        {
          "includes": [ "**/*.svelte" ],
          "formatter": { "enabled": true },
          "linter": { "enabled": true }
        }
      ]
    }
  '';

  configLookup = ''
    dir="''${file%/*}"
    [ "$dir" = "$file" ] && dir="."
    config_args=()
    probe="$dir"
    while [ -n "$probe" ] && [ "$probe" != "/" ]; do
      if [ -f "$probe/biome.json" ] || [ -f "$probe/biome.jsonc" ]; then
        config_args=(--config-path "$probe")
        break
      fi
      next="''${probe%/*}"
      [ "$next" = "$probe" ] && next="/"
      probe="$next"
    done
    if [ ''${#config_args[@]} -eq 0 ]; then
      config_args=(--config-path ${svelteBiomeConfig})
    fi
  '';

  svelteBiomeFormat = pkgs.writeShellScriptBin "svelte-biome-format" ''
    set -euo pipefail
    file="$1"
    ${configLookup}
    exec ${pkgs.biome}/bin/biome format \
      --stdin-file-path "$file" \
      --colors=off \
      "''${config_args[@]}"
  '';

  svelteBiomeLint = pkgs.writeShellScriptBin "svelte-biome-lint" ''
    set -euo pipefail
    file="$1"
    ${configLookup}
    exec ${pkgs.biome}/bin/biome lint \
      "$file" \
      --reporter=json \
      --diagnostic-level=warn \
      --colors=off \
      "''${config_args[@]}"
  '';
in
mkToolchain {
  runtime = with pkgs; [
    nodejs
    bun
  ];
  lsp = [
    pkgs.typescript-language-server
    pkgs.vscode-langservers-extracted
    pkgs.vue-language-server
    pkgs.angular-language-server
    pkgs.prisma-language-server
    pkgs.svelte-language-server
  ];
  formatter = [
    pkgs.prettierd
    svelteBiomeFormat
  ];
  linter = [
    pkgs.eslint_d
    svelteBiomeLint
  ];
  treesitter = with pkgs.tree-sitter-grammars; [
    tree-sitter-javascript
    tree-sitter-typescript
    tree-sitter-vue
    tree-sitter-svelte
  ];
  editor.lsp = {
    typescript = {
      command = [
        "typescript-language-server"
        "--stdio"
      ];
      extensions = [
        ".ts"
        ".tsx"
      ];
    };
    javascript = {
      command = [
        "typescript-language-server"
        "--stdio"
      ];
      extensions = [
        ".js"
        ".jsx"
        ".mjs"
        ".cjs"
      ];
    };
    vue = {
      command = [
        "vue-language-server"
        "--stdio"
      ];
      extensions = [ ".vue" ];
    };
    svelte = {
      command = [
        "svelteserver"
        "--stdio"
      ];
      extensions = [ ".svelte" ];
    };
  };
}
