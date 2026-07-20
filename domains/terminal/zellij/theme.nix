{
  t,
  p,
}:
  
''
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

''
