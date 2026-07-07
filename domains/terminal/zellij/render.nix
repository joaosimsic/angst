{
  themesLib,
  themeName,
  checkHelpers,
  ...
}:

let
  t = themesLib.get themeName;
  inherit (checkHelpers) requireInfix require;

  standard = "bg=#${t.ui.subtle},fg=#${t.ui.bg}";
  inactiveTab = "bg=#${t.ui.subtle},fg=#${t.ui.bg}";
  activeTab = "bg=#${t.ui.bg},fg=#${t.ui.subtle},bold";

  modeNormal = "bg=#${t.ui.subtle},fg=#${t.ui.bg},bold";
  modeLocked = "bg=#${t.ansi.normal.red},fg=#${t.ui.bg},bold";
  modePane = "bg=#${t.ansi.normal.green},fg=#${t.ui.bg},bold";
  modeTab = "bg=#${t.ansi.bright.magenta},fg=#${t.ui.bg},bold";
  modeScroll = "bg=#${t.ansi.normal.yellow},fg=#${t.ui.bg},bold";
  modeSearch = "bg=#${t.ansi.normal.magenta},fg=#${t.ui.bg},bold";
  modeResize = "bg=#${t.ui.accent},fg=#${t.ui.bg},bold";
  modeRename = "bg=#${t.ansi.normal.cyan},fg=#${t.ui.bg},bold";
  modeMove = "bg=#${t.ansi.bright.yellow},fg=#${t.ui.bg},bold";
  modeSession = "bg=#${t.ansi.normal.blue},fg=#${t.ui.bg},bold";
  modePrompt = "bg=#${t.diagnostic.success},fg=#${t.ui.bg},bold";
  modeTmux = "bg=#${t.ansi.bright.cyan},fg=#${t.ui.bg},bold";

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
                    name "move_focus_or_tab";
                    payload "right";
                    move_mod "ctrl";
                    use_arrow_keys "false";
                };
            }
        }
    }
  '';

  themeText = ''
        themes {
        angst {
            text_unselected {
                base "#${t.ui.fg}"
                background "#${t.ui.bg}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.accent}"
            }

            text_selected {
                base "#${t.ui.bg}"
                background "#${t.ui.accent}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.bright}"
            }

            ribbon_unselected {
                base "#${t.ui.subtle}"
                background "#${t.ui.surface}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.fg}"
            }

            ribbon_selected {
                base "#${t.ui.bg}"
                background "#${t.ui.accent}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.bright}"
            }

            table_title {
                base "#${t.ui.accent}"
                background "#${t.ui.bg}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.bright}"
            }

            table_cell_unselected {
                base "#${t.ui.fg}"
                background "#${t.ui.bg}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.subtle}"
            }

            table_cell_selected {
                base "#${t.ui.bg}"
                background "#${t.ui.accent}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.bright}"
            }

            list_unselected {
                base "#${t.ui.fg}"
                background "#${t.ui.bg}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.subtle}"
            }

            list_selected {
                base "#${t.ui.bg}"
                background "#${t.ui.accent}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.bright}"
            }

            frame_unselected {
                base "#${t.ui.border}"
                background "#${t.ui.bg}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.subtle}"
            }

            frame_selected {
                base "#${t.ui.accent}"
                background "#${t.ui.bg}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.bright}"
            }

            frame_highlight {
                base "#${t.diagnostic.warning}"
                background "#${t.ui.bg}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.accent}"
            }

            exit_code_success {
                base "#${t.diagnostic.success}"
                background "#${t.ui.bg}"
                emphasis_0 "#${t.diagnostic.success}"
                emphasis_1 "#${t.ui.fg}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.accent}"
            }

            exit_code_error {
                base "#${t.diagnostic.error}"
                background "#${t.ui.bg}"
                emphasis_0 "#${t.diagnostic.error}"
                emphasis_1 "#${t.diagnostic.warning}"
                emphasis_2 "#${t.diagnostic.info}"
                emphasis_3 "#${t.ui.accent}"
            }

            multiplayer_user_colors {
                player_1 "#${t.ansi.normal.magenta}"
                player_2 "#${t.ansi.normal.cyan}"
                player_3 "#${t.ansi.normal.yellow}"
                player_4 "#${t.ansi.normal.green}"
                player_5 "#${t.ansi.normal.blue}"
                player_6 "#${t.ansi.normal.red}"
                player_7 "#${t.ansi.bright.magenta}"
                player_8 "#${t.ansi.bright.cyan}"
                player_9 "#${t.ansi.bright.yellow}"
                player_10 "#${t.ansi.bright.green}"
            }
        }
    }

  '';

  layoutText = ''
    layout {
      default_tab_template {
        children
        pane size=1 borderless=true {
          plugin location="https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm" {
                    format_left   "{mode}"
                    format_center "#[${standard}]{command_cwd}"
                    format_right  "{tabs}"
                    format_space  "#[${standard}]"

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
      (requireInfix themeText "text_unselected {\n            base \"#${t.ui.fg}\""
        "zellij native text should render ${themeName} ui.fg"
      )
      (requireInfix themeText
        "ribbon_selected {\n            base \"#${t.ui.bg}\"\n            background \"#${t.ui.accent}\""
        "zellij selected ribbon should render ${themeName} ui.accent"
      )
      (requireInfix themeText "frame_unselected {\n            base \"#${t.ui.border}\""
        "zellij inactive frame should render ${themeName} ui.border"
      )
      (requireInfix themeText "frame_selected {\n            base \"#${t.ui.accent}\""
        "zellij active frame should render ${themeName} ui.accent"
      )
      (requireInfix themeText "frame_highlight {\n            base \"#${t.diagnostic.warning}\""
        "zellij highlighted frame should render ${themeName} diagnostic.warning"
      )
      (require (
        t.ui.accent != t.ui.bg
      ) "zellij selected ribbon must differ from background in ${themeName}")
      (require (
        t.ui.border != t.ui.bg
      ) "zellij inactive frame must differ from background in ${themeName}")
      (require (
        t.diagnostic.warning != t.ui.bg
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
      (requireInfix layoutText "mode_normal        \"#[bg=#${t.ui.accent},fg=#${t.ui.bg},bold]"
        "zellij normal mode should render ${themeName} ui.accent on ui.bg"
      )
      (requireInfix layoutText "mode_prompt        \"#[bg=#${t.diagnostic.success},fg=#${t.ui.bg},bold]"
        "zjstatus prompt mode should render ${themeName} diagnostic.success on ui.bg"
      )
      (requireInfix layoutText "format_left  \" {mode}  {tabs}\""
        "zellij format should use uniform bar background"
      )
      (requireInfix layoutText
        "format_right \"#[bg=#${t.ui.surface},fg=#${t.ui.comment}] {command_cwd} \""
        "zellij cwd should render ${themeName} ui.comment on ui.surface"
      )
      (requireInfix layoutText "tab_active              \"#[bg=#${t.ui.accent},fg=#${t.ui.bg},bold]"
        "zellij active tab should render ${themeName} ui.accent"
      )
      (requireInfix layoutText "tab_normal              \"#[bg=#${t.ui.surface},fg=#${t.ui.subtle}]"
        "zellij inactive tab should render ${themeName} ui.subtle on ui.surface"
      )
      (require (
        t.ui.accent != t.ui.surface
      ) "zellij active tab and bar surface must differ in ${themeName}")
      (require (
        t.ui.subtle != t.ui.surface
      ) "zellij inactive tab text and bar surface must differ in ${themeName}")
    ];
  }
]
