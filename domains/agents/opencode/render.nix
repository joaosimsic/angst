{
  lib,
  themeSys,
  themeName,
  checkHelpers,
  host,
  store ? { },
  ...
}:

let
  t = themeSys.get themeName;
  p = t.palette;
  inherit (checkHelpers) require requireInfix;

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
      diffAdded = "#${t.safe.textOn t.ansi.success}";
      diffRemoved = "#${t.safe.textOn t.ansi.error}";
      diffContext = "#${p.background.variant}";
      diffHunkHeader = "#${p.foreground.base}";
      diffHighlightAdded = "#${p.background.variant}";
      diffHighlightRemoved = "#${p.background.variant}";
      diffAddedBg = "#${t.ansi.success}";
      diffRemovedBg = "#${t.ansi.error}";
      diffContextBg = "#${p.background.variant}";
      diffLineNumber = "#${p.foreground.variant}";
      diffAddedLineNumberBg = "#${t.ansi.success}";
      diffRemovedLineNumberBg = "#${t.ansi.error}";
      markdownText = "#${p.foreground.variant}";
      markdownHeading = "#${p.accent.base}";
      markdownLink = "#${p.foreground.variant}";
      markdownLinkText = "#${p.accent.base}";
      markdownCode = "#${t.safe.textOn p.background.base}";
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

  mcpServers = lib.filterAttrs (_: v: v != null) {
    paper =
      if (store.hasPaper or false) then
        {
          type = "remote";
          url = "http://127.0.0.1:29979/mcp";
          enabled = true;
        }
      else
        null;

    rea =
      if (store.hasRea or false) then
        {
          type = "local";
          command = [
            "${host.pkgs.nodejs_24}/bin/npx"
            "-y"
            "rea-agents@6.5.0"
            "mcp"
          ];
          environment = {
            GHIDRA_INSTALL_DIR = "${host.pkgs.ghidra-bin}/lib/ghidra";
            JAVA_HOME = "${host.pkgs.openjdk21.home}";
            REA_GHIDRA_STARTUP_TIMEOUT_MS = "900000";
            GHIDRA_HEADLESS_MAXMEM = "4G";
          };
          enabled = true;
        }
      else
        null;
  };

  opencodeConfig = builtins.toJSON (
    {
      "$schema" = "https://opencode.ai/config.json";
      compaction = {
        auto = true;
        reserved = 10000;
      };
      provider = {
        opencode-go = {
          options = {
            apiKey = "{file:~/.secrets/opencode-go-key}";
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
    }
    // lib.optionalAttrs (mcpServers != { }) { mcp = mcpServers; }
  );
in
[
  {
    path = "domains/agents/opencode/config/tui.json";
    text = tuiConfig;
  }
  {
    path = "domains/agents/opencode/config/themes/angst.json";
    text = theme;
    checks = [
      (requireInfix theme ''"diffAdded":"#${t.safe.textOn t.ansi.success}"''
        "opencode diffAdded text should render ${themeName} safe text on ansi.success"
      )
      (requireInfix theme ''"diffRemoved":"#${t.safe.textOn t.ansi.error}"''
        "opencode diffRemoved text should render ${themeName} safe text on ansi.error"
      )
      (require (
        themeSys.contrast.contrastRatio (t.safe.textOn t.ansi.success) t.ansi.success >= 3.0
      ) "opencode diffAdded text must reach contrast floor 3.0 in ${themeName}")
      (require (
        themeSys.contrast.contrastRatio (t.safe.textOn t.ansi.error) t.ansi.error >= 3.0
      ) "opencode diffRemoved text must reach contrast floor 3.0 in ${themeName}")
    ];
  }
  {
    path = "domains/agents/opencode/config/opencode.jsonc";
    text = opencodeConfig;
  }
]
