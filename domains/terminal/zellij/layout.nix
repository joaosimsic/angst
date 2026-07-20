{
  standard,
  inactiveTab,
  activeTab,
  modeNormal,
  modeLocked,
  modePane,
  modeTab,
  modeScroll,
  modeSearch,
  modeResize,
  modeRename,
  modeMove,
  modeSession,
  modePrompt,
  modeTmux,
  fmtLeft,
  fmtCenter,
  fmtRight,
  fmtSpace,
}:

''
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
''
