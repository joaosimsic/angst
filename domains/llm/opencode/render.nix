{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;

  theme = builtins.toJSON {
    theme = {
      primary = "#${t.ACCENT}";
      secondary = "#${t.BRIGHT}";
      accent = "#${t.ACCENT}";
      error = "#${t.ERROR}";
      warning = "#${t.WARNING}";
      success = "#${t.SUCCESS}";
      info = "#${t.INFO}";
      text = "#${t.FG}";
      textMuted = "#${t.MUTED}";
      background = "#${t.BG}";
      backgroundPanel = "#${t.SURFACE}";
      backgroundElement = "#${t.ui.surface}";
      border = "#${t.ui.border}";
      borderActive = "#${t.ACCENT}";
      borderSubtle = "#${t.SUBTLE}";
      diffAdded = "#${t.GREEN}";
      diffRemoved = "#${t.RED}";
      diffContext = "#${t.COMMENT}";
      diffHunkHeader = "#${t.ui.border}";
      diffHighlightAdded = "#${t.GREEN_BRIGHT}";
      diffHighlightRemoved = "#${t.RED_BRIGHT}";
      diffAddedBg = "#${t.SURFACE}";
      diffRemovedBg = "#${t.SURFACE}";
      diffContextBg = "#${t.BG}";
      diffLineNumber = "#${t.DIM}";
      diffAddedLineNumberBg = "#${t.SURFACE}";
      diffRemovedLineNumberBg = "#${t.SURFACE}";
      markdownText = "#${t.FG}";
      markdownHeading = "#${t.ACCENT}";
      markdownLink = "#${t.BRIGHT}";
      markdownLinkText = "#${t.ACCENT}";
      markdownCode = "#${t.GREEN}";
      markdownBlockQuote = "#${t.COMMENT}";
      markdownEmph = "#${t.YELLOW}";
      markdownStrong = "#${t.BRIGHT}";
      markdownHorizontalRule = "#${t.SUBTLE}";
      markdownListItem = "#${t.ACCENT}";
      markdownListEnumeration = "#${t.ACCENT}";
      markdownImage = "#${t.BRIGHT}";
      markdownImageText = "#${t.SUBTLE}";
      markdownCodeBlock = "#${t.FG}";
      syntaxComment = "#${t.syntax.comment}";
      syntaxKeyword = "#${t.syntax.keyword}";
      syntaxFunction = "#${t.syntax.function}";
      syntaxVariable = "#${t.syntax.variable}";
      syntaxString = "#${t.syntax.string}";
      syntaxNumber = "#${t.syntax.number}";
      syntaxType = "#${t.syntax.type}";
      syntaxOperator = "#${t.syntax.operator}";
      syntaxPunctuation = "#${t.syntax.punctuation}";
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
