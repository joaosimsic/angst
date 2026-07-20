{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;
  p = t.palette;

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
      diffAdded = "#${p.background.base}";
      diffRemoved = "#${p.background.base}";
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
]
