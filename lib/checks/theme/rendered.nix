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
  zellijConfig = renderDomainOutputFor "personal" themeName "domains/terminal/zellij/config/config.kdl";
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
    (requireInfix zellijConfig "theme \"angst\""
      "zellij config should select the generated angst theme")
    (requireInfix zellijConfig "default_layout \"default\""
      "zellij config should select the custom default layout")
    (requireInfix zellijConfig "text_unselected {\n                  base \"#${theme.ui.fg}\""
      "zellij native text should render ${themeName} ui.fg")
    (requireInfix zellijConfig "ribbon_selected {\n                  base \"#${theme.ui.bg}\"\n                  background \"#${theme.ui.accent}\""
      "zellij selected ribbon should render ${themeName} ui.accent")
    (requireInfix zellijConfig "frame_unselected {\n                  base \"#${theme.ui.border}\""
      "zellij inactive frame should render ${themeName} ui.border")
    (requireInfix zellijConfig "frame_selected {\n                  base \"#${theme.ui.accent}\""
      "zellij active frame should render ${themeName} ui.accent")
    (requireInfix zellijConfig "frame_highlight {\n                  base \"#${theme.diagnostic.warning}\""
      "zellij highlighted frame should render ${themeName} diagnostic.warning")
    (require (theme.ui.accent != theme.ui.bg)
      "zellij selected ribbon must differ from background in ${themeName}")
    (require (theme.ui.border != theme.ui.bg)
      "zellij inactive frame must differ from background in ${themeName}")
    (require (theme.diagnostic.warning != theme.ui.bg)
      "zellij highlighted frame must differ from background in ${themeName}")
    (requireInfix zellijLayout "mode_default_to_mode \"normal\""
      "zjstatus should fall back to normal mode formatting")
    (requireInfix zellijLayout "mode_normal        \"#[bg=#${theme.ui.accent},fg=#${theme.ui.bg},bold]"
      "zellij normal mode should render ${themeName} ui.accent on ui.bg")
    (requireInfix zellijLayout "mode_prompt        \"#[bg=#${theme.diagnostic.success},fg=#${theme.ui.bg},bold]"
      "zjstatus prompt mode should render ${themeName} diagnostic.success on ui.bg")
    (requireInfix zellijLayout "format_left  \" {mode}  {tabs}\""
      "zellij format should use uniform bar background")
    (requireInfix zellijLayout "format_right \"#[bg=#${theme.ui.surface},fg=#${theme.ui.comment}] {command_cwd} \""
      "zellij cwd should render ${themeName} ui.comment on ui.surface")
    (requireInfix zellijLayout "tab_active              \"#[bg=#${theme.ui.accent},fg=#${theme.ui.bg},bold]"
      "zellij active tab should render ${themeName} ui.accent")
    (requireInfix zellijLayout "tab_normal              \"#[bg=#${theme.ui.surface},fg=#${theme.ui.subtle}]"
      "zellij inactive tab should render ${themeName} ui.subtle on ui.surface")
    (require (theme.ui.accent != theme.ui.surface)
      "zellij active tab and bar surface must differ in ${themeName}")
    (require (theme.ui.subtle != theme.ui.surface)
      "zellij inactive tab text and bar surface must differ in ${themeName}")
  ];

  _ = map (check: check) checks;
in
pkgs.writeText "theme-rendered-check" "ok"
