{
  themesLib,
  themeName,
  checkHelpers,
  ...
}:

let
  t = themesLib.get themeName;
  p = t.palette;
  inherit (checkHelpers) requireInfix require;

  standard = "bg=#${p.surface.variant},fg=#${t.safe.foregroundOnSurfaceVariant}";
  inactiveTab = "bg=#${p.surface.variant},fg=#${t.safe.foregroundOnSurfaceVariant},bold";
  activeTab = "bg=#${t.safe.surfaceVariantOnForegroundVariant},fg=#${p.surface.variant},bold";

  modeNormal = "bg=#${p.surface.variant},fg=#${t.safe.foregroundOnSurfaceVariant},bold";
  modeLocked = "bg=#${p.dim},fg=#${p.background.base},bold";
  modePane = "bg=#${p.surface.base},fg=#${t.safe.foregroundOnSurfaceBase},bold";
  modeTab = "bg=#${p.accent.variant},fg=#${t.safe.foregroundOnAccentVariant},bold";
  modeScroll = "bg=#${p.accent.base},fg=#${p.background.base},bold";
  modeSearch = "bg=#${p.accent.variant},fg=#${p.background.base},bold";
  modeResize = "bg=#${p.accent.base},fg=#${p.background.base},bold";
  modeRename = "bg=#${p.accent.variant},fg=#${p.background.base},bold";
  modeMove = "bg=#${p.accent.base},fg=#${p.background.base},bold";
  modeSession = "bg=#${p.surface.base},fg=#${p.background.base},bold";
  modePrompt = "bg=#${t.ansi.success},fg=#${p.background.base},bold";
  modeTmux = "bg=#${p.foreground.base},fg=#${p.background.base},bold";

  fmtLeft = "{mode}";
  fmtCenter = "#[${standard}]{command_cwd}";
  fmtRight = "#[${standard}]{tabs}";
  fmtSpace = "#[${standard}]";

  configText = ''
    plugins {
        vim-navigator location="https://github.com/hiasr/vim-zellij-navigator/releases/download/0.3.0/vim-zellij-navigator.wasm"
    }

    theme "angst"
    default_layout "default"
    pane_frames false
    auto_layout true
    copy_clipboard "system"
    show_startup_tips false
    show_release_notes false
    scrollback_editor "nvim +ZellijScrollback"

    keybinds clear-defaults=true {
        locked {
            bind "Ctrl g" { SwitchToMode "normal"; }
        }

        normal {
            bind "Ctrl g" { SwitchToMode "locked"; }
            bind "Ctrl p" { SwitchToMode "pane"; }
            bind "Ctrl t" { SwitchToMode "tab"; }
            bind "Ctrl s" { SwitchToMode "scroll"; }
        }

        pane {
            bind "h" { MovePane "Left"; }
            bind "Ctrl h" { MoveFocus "Left"; }
            bind "j" { MoveFocus "Down"; }
            bind "k" { MoveFocus "Up"; }
            bind "l" { MovePane "Right"; }
            bind "Ctrl l" { MoveFocus "Right"; }
            bind "n" { NewPane "Right"; }
            bind "x" { CloseFocus; }
            bind "=" { Resize "Increase"; }
            bind "-" { Resize "Decrease"; }
            bind "Esc" "Ctrl c" { SwitchToMode "normal"; }
        }

        tab {
            bind "h" { GoToPreviousTab; }
            bind "l" { GoToNextTab; }
            bind "n" { NewTab; }
            bind "x" { CloseTab; }
            bind "1" { GoToTab 1; }
            bind "2" { GoToTab 2; }
            bind "3" { GoToTab 3; }
            bind "4" { GoToTab 4; }
            bind "5" { GoToTab 5; }
            bind "6" { GoToTab 6; }
            bind "7" { GoToTab 7; }
            bind "8" { GoToTab 8; }
            bind "9" { GoToTab 9; }
            bind "Esc" "Ctrl c" { SwitchToMode "normal"; }
        }

        scroll {
            bind "j" "Down" { ScrollDown; }
            bind "k" "Up" { ScrollUp; }
            bind "Ctrl d" { HalfPageScrollDown; }
            bind "Ctrl u" { HalfPageScrollUp; }
            bind "g" { ScrollToTop; }
            bind "G" { ScrollToBottom; }
            bind "v" { EditScrollback; SwitchToMode "normal"; }
            bind "V" { EditScrollback; SwitchToMode "normal"; }
            bind "y" "c" { Copy; }
            bind "Esc" "Ctrl c" { SwitchToMode "normal"; }
        }


        shared_except "locked" {
            bind "Ctrl h" {
                MessagePlugin "vim-navigator" {
                    name "move_focus_or_tab";
                    payload "left";
                    move_mod "ctrl";
                    use_arrow_keys "false";
                };
            }

            bind "Ctrl j" {
                MessagePlugin "vim-navigator" {
                    name "move_focus";
                    payload "down";
                    move_mod "ctrl";
                    use_arrow_keys "false";
                };
            }

            bind "Ctrl k" {
                MessagePlugin "vim-navigator" {
                    name "move_focus";
                    payload "up";
                    move_mod "ctrl";
                    use_arrow_keys "false";
                };
            }

            bind "Ctrl l" {
                MessagePlugin "vim-navigator" {
                    name "move_focus_or_tab";
                    payload "right";
                    move_mod "ctrl";
                    use_arrow_keys "false";
                };
            }

            bind "Alt h" {
                MessagePlugin "vim-navigator" {
                    name "resize";
                    payload "left";
                    resize_mod "alt";
                };
            }

            bind "Alt j" {
                MessagePlugin "vim-navigator" {
                    name "resize";
                    payload "down";
                    resize_mod "alt";
                };
            }

            bind "Alt k" {
                MessagePlugin "vim-navigator" {
                    name "resize";
                    payload "up";
                    resize_mod "alt";
                };
            }

            bind "Alt l" {
                MessagePlugin "vim-navigator" {
                    name "resize";
                    payload "right";
                    resize_mod "alt";
                };
            }
        }
    }
  '';

  themeText = import ./theme.nix { inherit t p; };
  layoutText = import ./layout.nix {
    inherit
      standard
      inactiveTab
      activeTab
      modeNormal
      modeLocked
      modePane
      modeTab
      modeScroll
      modeSearch
      modeResize
      modeRename
      modeMove
      modeSession
      modePrompt
      modeTmux
      fmtLeft
      fmtCenter
      fmtRight
      fmtSpace
      ;
  };
in
[
  {
    path = "domains/terminal/zellij/config/config.kdl";
    text = configText;
    checks = [
      (requireInfix configText "theme \"angst\"" "zellij config should select the generated angst theme")
      (requireInfix configText "default_layout \"default\""
        "zellij config should select the custom default layout"
      )
    ];
  }
  {
    path = "domains/terminal/zellij/config/themes/angst.kdl";
    text = themeText;
    checks = [
      (requireInfix themeText "text_unselected {\n            base \"#${p.foreground.base}\""
        "zellij native text should render ${themeName} foreground.base"
      )
      (requireInfix themeText
        "ribbon_selected {\n            base \"#${p.background.base}\"\n            background \"#${p.accent.base}\""
        "zellij selected ribbon should render ${themeName} accent.base"
      )
      (requireInfix themeText "frame_unselected {\n            base \"#${p.foreground.base}\""
        "zellij inactive frame should render ${themeName} foreground.base"
      )
      (requireInfix themeText "frame_selected {\n            base \"#${p.accent.base}\""
        "zellij active frame should render ${themeName} accent.base"
      )
      (requireInfix themeText "frame_highlight {\n            base \"#${t.ansi.warn}\""
        "zellij highlighted frame should render ${themeName} ansi.warn"
      )
      (require (
        p.accent.base != p.background.base
      ) "zellij selected ribbon must differ from background in ${themeName}")
      (require (
        p.foreground.base != p.background.base
      ) "zellij inactive frame must differ from background in ${themeName}")
      (require (
        t.ansi.warn != p.background.base
      ) "zellij highlighted frame must differ from background in ${themeName}")
    ];
  }
  {
    path = "domains/terminal/zellij/config/layouts/default.kdl";
    text = layoutText;
    checks = [
      (requireInfix layoutText "mode_default_to_mode \"normal\""
        "zjstatus should fall back to normal mode formatting"
      )
      (require (
        p.accent.base != p.background.variant
      ) "zellij active tab and bar surface must differ in ${themeName}")
      (require (
        p.accent.base != p.background.variant
      ) "zellij inactive tab text and bar surface must differ in ${themeName}")
    ];
  }
]
