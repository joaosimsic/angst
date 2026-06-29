{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;
in
[
  {
    path = "domains/terminal/zellij/config/layouts/default.kdl";
    text = ''
      layout {
          default_tab_template {
              children
              pane size=1 borderless=true {
                  plugin location="https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm" {
                      format_left  "{mode}#[bg=#${t.FG},fg=#${t.BG}]│ {tabs}"
                      format_center ""
                      format_right "#[bg=#${t.FG},fg=#${t.BG}] {command_cwd} "
                      format_space "#[bg=#${t.FG}] "

                      hide_frame_for_single_pane "true"

                      mode_normal        "#[bg=#${t.FG},fg=#${t.BG},bold] NORMAL  "
                      mode_locked        "#[bg=#${t.FG},fg=#${t.BG},bold] LOCKED  "
                      mode_pane          "#[bg=#${t.FG},fg=#${t.BG},bold] PANE    "
                      mode_tab           "#[bg=#${t.FG},fg=#${t.BG},bold] TAB     "
                      mode_scroll        "#[bg=#${t.FG},fg=#${t.BG},bold] SCROLL  "
                      mode_enter_search  "#[bg=#${t.FG},fg=#${t.BG},bold] SEARCH  "
                      mode_search        "#[bg=#${t.FG},fg=#${t.BG},bold] SEARCH  "
                      mode_resize        "#[bg=#${t.FG},fg=#${t.BG},bold] RESIZE  "
                      mode_rename_tab    "#[bg=#${t.FG},fg=#${t.BG},bold] RENAME  "
                      mode_rename_pane   "#[bg=#${t.FG},fg=#${t.BG},bold] RENAME  "
                      mode_move          "#[bg=#${t.FG},fg=#${t.BG},bold] MOVE    "
                      mode_session       "#[bg=#${t.FG},fg=#${t.BG},bold] SESSION "
                      mode_tmux          "#[bg=#${t.FG},fg=#${t.BG},bold] TMUX    "

                      tab_normal              "#[bg=#${t.SUBTLE},fg=#${t.BG}]  {index}  "
                      tab_normal_fullscreen   "#[bg=#${t.SUBTLE},fg=#${t.BG}]  {index}  "
                      tab_normal_sync         "#[bg=#${t.SUBTLE},fg=#${t.BG}]  {index}  "
                      tab_active              "#[bg=#${t.BRIGHT},fg=#${t.BG},bold]  {index}  "
                      tab_active_fullscreen   "#[bg=#${t.BRIGHT},fg=#${t.BG},bold]  {index}  "
                      tab_active_sync         "#[bg=#${t.BRIGHT},fg=#${t.BG},bold]  {index}  "
                      tab_separator           "#[bg=#${t.SUBTLE}] "

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
