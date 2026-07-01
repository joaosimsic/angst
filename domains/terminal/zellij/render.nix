{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;

  standard = "bg=#${t.ui.subtle},fg=#${t.ui.bg}";
  inactiveTab = "bg=#${t.ui.subtle},fg=#${t.ui.bg}";
  activeTab = "bg=#${t.ui.bg},fg=#${t.ui.subtle},bold";

  modeNormal   = "bg=#${t.ui.subtle},fg=#${t.ui.bg},bold";
  modeLocked   = "bg=#${t.ansi.normal.red},fg=#${t.ui.bg},bold";
  modePane     = "bg=#${t.ansi.normal.green},fg=#${t.ui.bg},bold";
  modeTab      = "bg=#${t.ansi.bright.magenta},fg=#${t.ui.bg},bold";
  modeScroll   = "bg=#${t.ansi.normal.yellow},fg=#${t.ui.bg},bold";
  modeSearch   = "bg=#${t.ansi.normal.magenta},fg=#${t.ui.bg},bold";
  modeResize   = "bg=#${t.ui.accent},fg=#${t.ui.bg},bold";
  modeRename   = "bg=#${t.ansi.normal.cyan},fg=#${t.ui.bg},bold";
  modeMove     = "bg=#${t.ansi.bright.yellow},fg=#${t.ui.bg},bold";
  modeSession  = "bg=#${t.ansi.normal.blue},fg=#${t.ui.bg},bold";
  modePrompt   = "bg=#${t.diagnostic.success},fg=#${t.ui.bg},bold";
  modeTmux     = "bg=#${t.ansi.bright.cyan},fg=#${t.ui.bg},bold";
in
[
  {
    path = "domains/terminal/zellij/config/config.kdl";
    text = ''
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
                      name "resize";
                      payload "right";
                      resize_mod "alt";
                  };
              }
          }
      }
    '';
  }
  {
    path = "domains/terminal/zellij/config/themes/angst.kdl";
    text = ''
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
  }
  {
    path = "domains/terminal/zellij/config/layouts/default.kdl";
    text = ''
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
  }
]
