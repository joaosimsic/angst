{ lib, pkgs, themesLib, renderTemplateFor }:

let
  themeName = "catppuccin-mocha";
  theme = themesLib.get themeName;

  require =
    condition: message:
    if condition then
      null
    else
      throw message;

  requireDistinct =
    label: tokens:
    let
      values = map (token: theme.${token}) tokens;
    in
    require (lib.length values == lib.length (lib.unique values))
      "${themeName} ${label} must use distinct hues (duplicates among ${lib.concatStringsSep ", " tokens})";

  requireInfix =
    haystack: needle: message:
    require (lib.hasInfix needle haystack) message;

  ghostty = renderTemplateFor "terminal/ghostty/config/colors.conf" themeName;
  starship = renderTemplateFor "shell/starship/config/starship.toml" themeName;
  nushell = renderTemplateFor "shell/nushell/config/colors.nu" themeName;
  zellijLayout = renderTemplateFor "terminal/zellij/config/layouts/default.kdl" themeName;

  checks = [
    (requireDistinct "palette tokens" [
      "RED"
      "GREEN"
      "YELLOW"
      "CYAN"
      "BLUE"
      "MAGENTA"
    ])
    (requireInfix ghostty "palette = 5=#${theme.BLUE}"
      "ghostty palette slot 5 should render catppuccin-mocha BLUE")
    (requireInfix ghostty "palette = 13=#${theme.MAGENTA}"
      "ghostty palette slot 13 should render catppuccin-mocha MAGENTA")
    (requireInfix ghostty "palette = 1=#${theme.RED}"
      "ghostty palette slot 1 should render catppuccin-mocha RED")
    (requireInfix starship "bold #${theme.SUCCESS}"
      "starship success_symbol should render catppuccin-mocha SUCCESS")
    (requireInfix starship "bold #${theme.ERROR}"
      "starship error_symbol should render catppuccin-mocha ERROR")
    (require (theme.SUCCESS != theme.ERROR)
      "starship semantic SUCCESS and ERROR must differ in catppuccin-mocha")
    (requireInfix nushell "shape_garbage:               { fg: \"#${theme.ERROR}\""
      "nushell shape_garbage should render catppuccin-mocha ERROR")
    (requireInfix nushell "shape_globpattern:           \"#${theme.INFO}\""
      "nushell shape_globpattern should render catppuccin-mocha INFO")
    (require (theme.ERROR != theme.INFO)
      "nushell semantic ERROR and INFO must differ in catppuccin-mocha")
    (requireInfix zellijLayout "tab_active              \"#[bg=#${theme.BRIGHT}"
      "zellij active tab should render catppuccin-mocha BRIGHT")
    (requireInfix zellijLayout "tab_normal              \"#[bg=#${theme.FG}"
      "zellij inactive tab should render catppuccin-mocha FG")
    (require (theme.BRIGHT != theme.FG)
      "zellij semantic BRIGHT and FG must differ in catppuccin-mocha")
  ];

  _ = map (check: check) checks;
in
pkgs.writeText "theme-rendered-check" "ok"
