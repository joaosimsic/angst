{ lib, themesLib, theme, fontFamily }:

let
  t = themesLib.get theme;
in
{
  inherit (t)
    FG
    BG
    BRIGHT
    MUTED
    COMMENT
    ERROR
    SUCCESS
    WARNING
    INFO
    BLACK
    RED
    GREEN
    YELLOW
    CYAN
    BLUE
    MAGENTA
    BASE
    DIM
    SUBTLE
    ACCENT
    SURFACE
    RED_BRIGHT
    GREEN_BRIGHT
    YELLOW_BRIGHT
    BLUE_BRIGHT
    MAGENTA_BRIGHT
    CYAN_BRIGHT
    ;

  FONT_FAMILY = fontFamily;

  UI_FG = t.ui.fg;
  UI_BG = t.ui.bg;
  UI_BRIGHT = t.ui.bright;
  UI_MUTED = t.ui.muted;
  UI_COMMENT = t.ui.comment;
  UI_SURFACE = t.ui.surface;
  UI_SUBTLE = t.ui.subtle;
  UI_ACCENT = t.ui.accent;
  UI_BORDER = t.ui.border;
  UI_SELECTION_BG = t.ui.selectionBg;
  UI_SELECTION_FG = t.ui.selectionFg;
  UI_OVERLAY = t.ui.overlay;
  UI_PROMPT = t.ui.prompt;

  SYNTAX_COMMENT = t.syntax.comment;
  SYNTAX_KEYWORD = t.syntax.keyword;
  SYNTAX_STRING = t.syntax.string;
  SYNTAX_FUNCTION = t.syntax.function;
  SYNTAX_VARIABLE = t.syntax.variable;
  SYNTAX_CONSTANT = t.syntax.constant;
  SYNTAX_OPERATOR = t.syntax.operator;
  SYNTAX_TYPE = t.syntax.type;
  SYNTAX_NUMBER = t.syntax.number;
  SYNTAX_PUNCTUATION = t.syntax.punctuation;

  DIAGNOSTIC_ERROR = t.diagnostic.error;
  DIAGNOSTIC_WARNING = t.diagnostic.warning;
  DIAGNOSTIC_INFO = t.diagnostic.info;
  DIAGNOSTIC_HINT = t.diagnostic.hint;
  DIAGNOSTIC_SUCCESS = t.diagnostic.success;
}
