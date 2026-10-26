{
  lib,
  themesLib,
  themeName,
  store ? { },
  ...
}:

let
  t = themesLib.get themeName;
  p = t.palette;

  diffAlpha = if t.isDark then 0.22 else 0.14;
  tint =
    base: color:
    let
      mixed = themesLib.mix {
        from = base;
        to = color;
        weight = diffAlpha;
      };
    in
    "#${mixed}";

  theme = builtins.toJSON {
    theme = {
      primary = "#${p.accent.base}";
      secondary = "#${p.foreground.variant}";
      accent = "#${p.accent.base}";
      error = "#${t.ansi.error}";
      warning = "#${t.ansi.warn}";
      success = "#${t.ansi.success}";
      info = "#${t.ansi.info}";
      text = "#${p.foreground.variant}";
      textMuted = "#${p.dim}";
      background = "#${p.background.base}";
      backgroundPanel = "#${p.background.variant}";
      backgroundElement = "#${p.background.variant}";
      border = "#${p.foreground.base}";
      borderActive = "#${p.accent.base}";
      borderSubtle = "#${p.accent.base}";
      diffAdded = "#${t.ansi.success}";
      diffRemoved = "#${t.ansi.error}";
      diffContext = "#${p.background.variant}";
      diffHunkHeader = "#${p.foreground.base}";
      diffHighlightAdded = "#${t.ansi.success}";
      diffHighlightRemoved = "#${t.ansi.error}";
      diffAddedBg = tint p.background.base t.ansi.success;
      diffRemovedBg = tint p.background.base t.ansi.error;
      diffContextBg = "#${p.background.variant}";
      diffLineNumber = "#${p.foreground.variant}";
      diffAddedLineNumberBg = tint p.background.variant t.ansi.success;
      diffRemovedLineNumberBg = tint p.background.variant t.ansi.error;
      markdownText = "#${p.foreground.variant}";
      markdownHeading = "#${p.accent.base}";
      markdownLink = "#${p.foreground.variant}";
      markdownLinkText = "#${p.accent.base}";
      markdownCode = "#${p.surface.variant}";
      markdownBlockQuote = "#${p.dim}";
      markdownEmph = "#${p.accent.base}";
      markdownStrong = "#${p.foreground.variant}";
      markdownHorizontalRule = "#${p.accent.base}";
      markdownListItem = "#${p.accent.base}";
      markdownListEnumeration = "#${p.accent.base}";
      markdownImage = "#${p.foreground.variant}";
      markdownImageText = "#${p.accent.base}";
      markdownCodeBlock = "#${p.foreground.variant}";
      syntaxComment = "#${p.dim}";
      syntaxKeyword = "#${p.accent.base}";
      syntaxFunction = "#${p.foreground.variant}";
      syntaxVariable = "#${p.foreground.variant}";
      syntaxString = "#${p.foreground.variant}";
      syntaxNumber = "#${p.accent.base}";
      syntaxType = "#${p.foreground.base}";
      syntaxOperator = "#${p.foreground.base}";
      syntaxPunctuation = "#${p.foreground.base}";
    };
  };

  tuiConfig = builtins.toJSON {
    theme = "angst";
    "$schema" = "https://opencode.ai/tui.json";
    plugin = [
      "./tui-plugins/session-nav.ts"
      "./tui-plugins/vim-indicator.tsx"
    ];
    keybinds = {
      messages_half_page_up = "ctrl+u";
      messages_half_page_down = "ctrl+d";
    };
  };

  lspWithMux = lib.mapAttrs (
    name: cfg:
    if name == "rust" && (store.hasLspmux or false) then
      cfg // { command = [ "rust-analyzer-mux" ]; }
    else
      cfg
  ) (store.editorLsp or { });

  lspWithDisabled = lspWithMux // {
    "php intelephense" = {
      disabled = true;
    };
  };

  # MCPs are project-local (repo-root opencode.json), not global HM config —
  # see lib/render.nix (vm) and per-project configs under ~/projects.
  opencodeConfig = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    compaction = {
      auto = true;
      reserved = 10000;
    };
    provider = {
      opencode-go = {
        options = {
          apiKey = "{env:OPENCODE_GO_API_KEY}";
        };
      };
    };
    lsp = lspWithDisabled;
    permission = {
      external_directory = {
        "/tmp/**" = "allow";
        "/nix/**" = "allow";
      };
    };
    agent = {
      "Auto" = {
        description = "Auto-approve all permission requests.";
        mode = "primary";
        color = "warning";
        permission = {
          "*" = "allow";
          # Match build's explicit allows (question, plan_enter) so Auto
          # is a superset of build, not more restrictive. Also allow
          # plan_exit so the model can leave plan mode itself instead of
          # getting trapped when a session switches plan -> Auto.
          "question" = "allow";
          "plan_enter" = "allow";
          "plan_exit" = "allow";
        };
      };
    };
    command = {
      caveman = {
        description = "Caveman voice: /caveman toggles on/off, or lite|full|ultra|off";
        template = ''
          Caveman control. Argument: "$ARGUMENTS"

          The caveman plugin already applied the mode.
          Reply with exactly one line using the Caveman level from your system instructions:
          Caveman level: <level>
        '';
      };
    };
  };
in
[
  {
    path = "domains/agents/opencode/config/tui.json";
    text = tuiConfig;
  }
  {
    path = "domains/agents/opencode/config/themes/angst.json";
    text = theme;
  }
  {
    path = "domains/agents/opencode/config/opencode.jsonc";
    text = opencodeConfig;
  }
]
