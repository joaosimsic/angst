{ lib, pkgs, themesLib, renderDomainOutputFor, themeName }:

let
  theme = themesLib.get themeName;
  inherit (import ./assertions.nix { inherit lib themeName theme; })
    require
    requireDistinct
    requireInfix
    ;

  ghostty = renderDomainOutputFor "personal" themeName "domains/terminal/ghostty/config/colors.conf";
  starship = renderDomainOutputFor "personal" themeName "domains/shell/starship/config/starship.toml";
  nushell = renderDomainOutputFor "personal" themeName "domains/shell/nushell/config/colors.nu";
  zellijLayout = renderDomainOutputFor "personal" themeName "domains/terminal/zellij/config/layouts/default.kdl";

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
      "ghostty palette slot 5 should render ${themeName} BLUE")
    (requireInfix ghostty "palette = 13=#${theme.MAGENTA}"
      "ghostty palette slot 13 should render ${themeName} MAGENTA")
    (requireInfix ghostty "palette = 1=#${theme.RED}"
      "ghostty palette slot 1 should render ${themeName} RED")
    (requireInfix starship "bold #${theme.ACCENT}"
      "starship directory style should render ${themeName} ACCENT")
    (requireInfix starship "bold #${theme.ERROR}"
      "starship error_symbol should render ${themeName} ERROR")
    (require (theme.SUCCESS != theme.ERROR)
      "starship semantic SUCCESS and ERROR must differ in ${themeName}")
    (requireInfix nushell "shape_garbage:               { fg: \"#${theme.ERROR}\""
      "nushell shape_garbage should render ${themeName} ERROR")
    (requireInfix nushell "shape_globpattern:           \"#${theme.INFO}\""
      "nushell shape_globpattern should render ${themeName} INFO")
    (require (theme.ERROR != theme.INFO)
      "nushell semantic ERROR and INFO must differ in ${themeName}")
    (requireInfix zellijLayout "tab_active              \"#[bg=#${theme.BRIGHT}"
      "zellij active tab should render ${themeName} BRIGHT")
    (requireInfix zellijLayout "tab_normal              \"#[bg=#${theme.FG}"
      "zellij inactive tab should render ${themeName} FG")
    (require (theme.BRIGHT != theme.FG)
      "zellij semantic BRIGHT and FG must differ in ${themeName}")
  ];

  _ = map (check: check) checks;
in
pkgs.writeText "theme-rendered-check" "ok"
