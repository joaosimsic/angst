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
      text = "#${p.foreground.base}";
      textMuted = "#${p.dim}";
      background = "#${p.background.base}";
      backgroundPanel = "#${p.background.variant}";
      backgroundElement = "#${p.background.variant}";
      border = "#${p.foreground.base}";
      borderActive = "#${p.accent.base}";
      borderSubtle = "#${p.accent.base}";
      diffAdded = "#${p.surface.variant}";
      diffRemoved = "#${p.dim}";
      diffContext = "#${p.dim}";
      diffHunkHeader = "#${p.foreground.base}";
      diffHighlightAdded = "#${p.surface.variant}";
      diffHighlightRemoved = "#${p.dim}";
      diffAddedBg = "#${p.background.variant}";
      diffRemovedBg = "#${p.background.variant}";
      diffContextBg = "#${p.background.base}";
      diffLineNumber = "#${p.dim}";
      diffAddedLineNumberBg = "#${p.background.variant}";
      diffRemovedLineNumberBg = "#${p.background.variant}";
      markdownText = "#${p.foreground.base}";
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
      markdownCodeBlock = "#${p.foreground.base}";
      syntaxComment = "#${p.dim}";
      syntaxKeyword = "#${p.accent.base}";
      syntaxFunction = "#${p.foreground.base}";
      syntaxVariable = "#${p.foreground.base}";
      syntaxString = "#${p.foreground.variant}";
      syntaxNumber = "#${p.accent.base}";
      syntaxType = "#${p.surface.base}";
      syntaxOperator = "#${p.accent.base}";
      syntaxPunctuation = "#${p.accent.base}";
    };
  };

  tuiConfig = builtins.toJSON {
    theme = "angst";
    "$schema" = "https://opencode.ai/tui.json";
  };
in
[
  {
    path = "domains/llm/opencode/config/tui.json";
    text = tuiConfig;
  }
  {
    path = "domains/llm/opencode/config/themes/angst.json";
    text = theme;
  }
]
