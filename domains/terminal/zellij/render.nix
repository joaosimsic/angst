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

  standard = "bg=#${p.surface.variant},fg=#${p.foreground.variant}";
  inactiveTab = "bg=#${p.surface.variant},fg=#${p.foreground.variant},bold";
  activeTab = "bg=#${p.foreground.variant},fg=#${p.surface.variant},bold";

  modeNormal = "bg=#${p.surface.variant},fg=#${p.foreground.variant},bold";
  modeLocked = "bg=#${p.dim},fg=#${p.background.base},bold";
  modePane = "bg=#${p.surface.base},fg=#${p.foreground.variant},bold";
  modeTab = "bg=#${p.accent.variant},fg=#${p.foreground.variant},bold";
  modeScroll = "bg=#${p.accent.base},fg=#${p.background.base},bold";
  modeSearch = "bg=#${p.accent.variant},fg=#${p.background.base},bold";
  modeResize = "bg=#${p.accent.base},fg=#${p.background.base},bold";
  modeRename = "bg=#${p.accent.variant},fg=#${p.background.base},bold";
  modeMove = "bg=#${p.accent.base},fg=#${p.background.base},bold";
  modeSession = "bg=#${p.surface.base},fg=#${p.background.base},bold";
  modePrompt = "bg=#${t.ansi.success},fg=#${p.background.base},bold";
  modeTmux = "bg=#${p.foreground.base},fg=#${p.background.base},bold";

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

    keybinds clear-defaults=true {
        locked {
            bind "Ctrl g" { SwitchToMode "normal"; }
        }

        normal {
            bind "Ctrl g" { SwitchToMode "locked"; }
            bind "Ctrl p" { SwitchToMode "pane"; }
            bind "Ctrl t" { SwitchToMode "tab"; }
        }

        pane {
            bind "h" { MoveFocus "Left"; }
            bind "j" { MoveFocus "Down"; }
            bind "k" { MoveFocus "Up"; }
            bind "l" { MoveFocus "Right"; }
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

  themeText = ''
        themes {
        angst {
            text_unselected {
                base "#${p.foreground.base}"
                background "#${p.background.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.accent.base}"
            }

            text_selected {
                base "#${p.background.base}"
                background "#${p.accent.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.foreground.variant}"
            }

            ribbon_unselected {
                base "#${p.accent.base}"
                background "#${p.background.variant}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.foreground.base}"
            }

            ribbon_selected {
                base "#${p.background.base}"
                background "#${p.accent.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.foreground.variant}"
            }

            table_title {
                base "#${p.accent.base}"
                background "#${p.background.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.foreground.variant}"
            }

            table_cell_unselected {
                base "#${p.foreground.base}"
                background "#${p.background.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.accent.base}"
            }

            table_cell_selected {
                base "#${p.background.base}"
                background "#${p.accent.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.foreground.variant}"
            }

            list_unselected {
                base "#${p.foreground.base}"
                background "#${p.background.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.accent.base}"
            }

            list_selected {
                base "#${p.background.base}"
                background "#${p.accent.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.foreground.variant}"
            }

            frame_unselected {
                base "#${p.foreground.base}"
                background "#${p.background.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.accent.base}"
            }

            frame_selected {
                base "#${p.accent.base}"
                background "#${p.background.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.foreground.variant}"
            }

            frame_highlight {
                base "#${t.ansi.warn}"
                background "#${p.background.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.accent.base}"
            }

            exit_code_success {
                base "#${t.ansi.success}"
                background "#${p.background.base}"
                emphasis_0 "#${t.ansi.success}"
                emphasis_1 "#${p.foreground.base}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.accent.base}"
            }

            exit_code_error {
                base "#${t.ansi.error}"
                background "#${p.background.base}"
                emphasis_0 "#${t.ansi.error}"
                emphasis_1 "#${t.ansi.warn}"
                emphasis_2 "#${t.ansi.info}"
                emphasis_3 "#${p.accent.base}"
            }

            multiplayer_user_colors {
                player_1 "#${p.accent.variant}"
                player_2 "#${p.foreground.base}"
                player_3 "#${p.accent.base}"
                player_4 "#${p.surface.variant}"
                player_5 "#${p.surface.base}"
                player_6 "#${p.dim}"
                player_7 "#${p.accent.variant}"
                player_8 "#${p.foreground.base}"
                player_9 "#${p.accent.base}"
                player_10 "#${p.surface.variant}"
            }
        }
    }

  '';

  fmtLeft = "{mode}";
  fmtCenter = "#[${standard}]{command_cwd}";
  fmtRight = "#[${standard}]{tabs}";
  fmtSpace = "#[${standard}]";

  layoutText = ''
    layout {
      default_tab_template {
        children
        pane size=1 borderless=true {
          plugin location="https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm" {
                    format_left   "${fmtLeft}"
                    format_center "${fmtCenter}"
                    format_right  "${fmtRight}"
                    format_space  "${fmtSpace}"

                    mode_default_to_mode "normal"
                    mode_normal        "#[${modeNormal}] NORMAL "
                    mode_locked        "#[${modeLocked}] LOCKED "
                    mode_pane          "#[${modePane}] PANE "
                    mode_tab           "#[${modeTab}] TAB "
                    mode_scroll        "#[${modeScroll}] SCROLL "
                    mode_enter_search  "#[${modeSearch}] SEARCH "
                    mode_search        "#[${modeSearch}] SEARCH "
                    mode_resize        "#[${modeResize}] RESIZE "
                    mode_rename_tab    "#[${modeRename}] RENAME "
                    mode_rename_pane   "#[${modeRename}] RENAME "
                    mode_move          "#[${modeMove}] MOVE "
                    mode_session       "#[${modeSession}] SESSION "
                    mode_prompt        "#[${modePrompt}] PROMPT "
                    mode_tmux          "#[${modeTmux}] TMUX "

                    tab_normal              "#[${inactiveTab}] {index} "
                    tab_normal_fullscreen   "#[${inactiveTab}] {index} "
                    tab_normal_sync         "#[${inactiveTab}] {index} "
                    tab_active              "#[${activeTab}] {index} "
                    tab_active_fullscreen   "#[${activeTab}] {index} "
                    tab_active_sync         "#[${activeTab}] {index} "

                    command_cwd_command    "pwd"
                    command_cwd_format     "{stdout}"
                    command_cwd_interval   "0"
                    command_cwd_rendermode "dynamic"
                }
            }
        }
    }
  '';
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
