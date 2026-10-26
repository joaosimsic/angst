{
  themeSys,
  themeName,
  checkHelpers,
}:

let
  t = themeSys.get themeName;
  p = t.palette;
  inherit (checkHelpers) requireInfix require;

  standard = "bg=#${p.surface.variant},fg=#${t.safe.foregroundOnSurfaceVariant}";
  inactiveTab = "bg=#${p.surface.variant},fg=#${t.safe.foregroundOnSurfaceVariant},bold";
  activeTab = "bg=#${t.safe.surfaceVariantOnForegroundVariant},fg=#${p.surface.variant},bold";

  modeNormal = "bg=#${p.surface.variant},fg=#${t.safe.foregroundOnSurfaceVariant},bold";
  modeLocked = "bg=#${p.dim},fg=#${t.safe.textOn p.dim},bold";
  modePane = "bg=#${p.surface.base},fg=#${t.safe.foregroundOnSurfaceBase},bold";
  modeTab = "bg=#${p.accent.variant},fg=#${t.safe.foregroundOnAccentVariant},bold";
  modeScroll = "bg=#${p.accent.base},fg=#${t.safe.textOn p.accent.base},bold";
  modeSearch = "bg=#${p.accent.variant},fg=#${t.safe.textOn p.accent.variant},bold";
  modeResize = "bg=#${p.accent.base},fg=#${t.safe.textOn p.accent.base},bold";
  modeRename = "bg=#${p.accent.variant},fg=#${t.safe.textOn p.accent.variant},bold";
  modeMove = "bg=#${p.accent.base},fg=#${t.safe.textOn p.accent.base},bold";
  modeSession = "bg=#${p.surface.base},fg=#${t.safe.textOn p.surface.base},bold";
  modePrompt = "bg=#${t.ansi.success},fg=#${t.safe.textOn t.ansi.success},bold";
  modeTmux = "bg=#${p.foreground.base},fg=#${t.safe.textOn p.foreground.base},bold";

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
            bind "Ctrl m" { SwitchToMode "move"; }
        }

        pane {
            bind "h" "Left" { MoveFocus "Left"; }
            bind "j" "Down" { MoveFocus "Down"; }
            bind "k" "Up" { MoveFocus "Up"; }
            bind "l" "Right" { MoveFocus "Right"; }
            bind "n" { NewPane "Right"; }
            bind "x" { CloseFocus; }
            bind "=" { Resize "Increase"; }
            bind "-" { Resize "Decrease"; }
            bind "Esc" "Ctrl c" { SwitchToMode "normal"; }
        }

        move {
            bind "h" "Left" { MovePane "Left"; }
            bind "j" "Down" { MovePane "Down"; }
            bind "k" "Up" { MovePane "Up"; }
            bind "l" "Right" { MovePane "Right"; }
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
        "ribbon_selected {\n            base \"#${t.safe.textOn p.accent.base}\"\n            background \"#${p.accent.base}\""
        "zellij selected ribbon should render ${themeName} safe text on accent.base"
      )
      (requireInfix themeText "frame_unselected {\n            base \"#${p.foreground.base}\""
        "zellij inactive frame should render ${themeName} foreground.base"
      )
      (requireInfix themeText "frame_selected {\n            base \"#${t.safe.textOn p.background.base}\""
        "zellij active frame should render ${themeName} safe text on background.base"
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
      (require (
        themeSys.contrast.contrastRatio (t.safe.textOn p.accent.base) p.accent.base >= 3.0
      ) "zellij selected-row text must reach contrast floor 3.0 in ${themeName}")
      (require (
        themeSys.contrast.contrastRatio (t.safe.textOn p.background.base) p.background.base >= 3.0
      ) "zellij frame/title text must reach contrast floor 3.0 in ${themeName}")
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
