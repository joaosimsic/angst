{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;

  bar = "bg=#${t.ui.surface},fg=#${t.ui.fg}";
  mode = "bg=#${t.ui.prompt},fg=#${t.ui.bg},bold";
  separator = "bg=#${t.ui.surface},fg=#${t.ui.border}";
  inactiveTab = "bg=#${t.ui.surface},fg=#${t.ui.subtle}";
  activeTab = "bg=#${t.ui.accent},fg=#${t.ui.bg},bold";
  cwd = "bg=#${t.ui.surface},fg=#${t.ui.comment}";
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
      pane_frames true

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

      copy_command "xclip -selection clipboard"
      copy_clipboard "system"

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
    path = "domains/terminal/zellij/config/layouts/default.kdl";
    text = ''
      layout {
          default_tab_template {
              children
              pane size=1 borderless=true {
                  plugin location="https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm" {
                      format_left  "{mode}#[${separator}]│ {tabs}"
                      format_center ""
                      format_right "#[${cwd}] {command_cwd} "
                      format_space "#[${bar}] "

                      hide_frame_for_single_pane "true"

                      mode_default_to_mode "normal"
                      mode_normal        "#[${mode}] NORMAL  "
                      mode_locked        "#[${mode}] LOCKED  "
                      mode_pane          "#[${mode}] PANE    "
                      mode_tab           "#[${mode}] TAB     "
                      mode_scroll        "#[${mode}] SCROLL  "
                      mode_enter_search  "#[${mode}] SEARCH  "
                      mode_search        "#[${mode}] SEARCH  "
                      mode_resize        "#[${mode}] RESIZE  "
                      mode_rename_tab    "#[${mode}] RENAME  "
                      mode_rename_pane   "#[${mode}] RENAME  "
                      mode_move          "#[${mode}] MOVE    "
                      mode_session       "#[${mode}] SESSION "
                      mode_prompt        "#[${mode}] PROMPT  "
                      mode_tmux          "#[${mode}] TMUX    "

                      tab_normal              "#[${inactiveTab}]  {index}  "
                      tab_normal_fullscreen   "#[${inactiveTab}]  {index}  "
                      tab_normal_sync         "#[${inactiveTab}]  {index}  "
                      tab_active              "#[${activeTab}]  {index}  "
                      tab_active_fullscreen   "#[${activeTab}]  {index}  "
                      tab_active_sync         "#[${activeTab}]  {index}  "
                      tab_separator           "#[${bar}] "

                      command_cwd_command    "pwd"
                      command_cwd_format     "{stdout}"
                      command_cwd_interval   "1"
                      command_cwd_rendermode "static"
                  }
              }
          }
      }
    '';
  }
]
