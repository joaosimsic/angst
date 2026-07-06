let
  ansiTokens = [
    "black"
    "red"
    "green"
    "yellow"
    "blue"
    "magenta"
    "cyan"
    "white"
  ];

  paletteTokens = [
    "black"
    "base"
    "dim"
    "subtle"
    "accent"
    "surface"
    "overlay"
  ];

  uiTokens = [
    "fg"
    "bg"
    "bright"
    "muted"
    "comment"
    "surface"
    "subtle"
    "accent"
    "border"
    "selectionBg"
    "selectionFg"
    "overlay"
    "prompt"
  ];

  syntaxTokens = [
    "comment"
    "keyword"
    "string"
    "function"
    "variable"
    "constant"
    "operator"
    "type"
    "number"
    "punctuation"
  ];

  diagnosticTokens = [
    "error"
    "warning"
    "info"
    "hint"
    "success"
  ];
in
{
  inherit
    ansiTokens
    paletteTokens
    uiTokens
    syntaxTokens
    diagnosticTokens
    ;

  legacyTokens = [
    "FG"
    "BG"
    "BRIGHT"
    "MUTED"
    "COMMENT"
    "ERROR"
    "SUCCESS"
    "WARNING"
    "INFO"
    "BLACK"
    "RED"
    "GREEN"
    "YELLOW"
    "CYAN"
    "BLUE"
    "MAGENTA"
    "BASE"
    "DIM"
    "SUBTLE"
    "ACCENT"
    "SURFACE"
  ];
}
