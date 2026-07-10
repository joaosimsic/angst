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

  colorsText = ''
    $env.config.color_config = {
        separator:                   "#${p.dim}"
        leading_trailing_space_bg:   { attr: n }
        header:                      { fg: "#${p.foreground.base}" attr: b }
        empty:                       "#${p.dim}"
        bool:                        "#${p.foreground.variant}"
        int:                         "#${p.foreground.base}"
        filesize:                    "#${p.foreground.base}"
        duration:                    "#${p.foreground.base}"
        date:                        "#${p.foreground.variant}"
        range:                       "#${p.foreground.base}"
        float:                       "#${p.foreground.base}"
        string:                      "#${p.foreground.base}"
        nothing:                     "#${p.dim}"
        binary:                      "#${p.dim}"
        cell_path:                   "#${p.foreground.variant}"
        row_index:                   { fg: "#${p.dim}" attr: b }
        record:                      "#${p.foreground.base}"
        list:                        "#${p.foreground.base}"
        block:                       "#${p.foreground.base}"
        hints:                       "#${p.dim}"
        search_result:               { fg: "#${p.background.base}" bg: "#${p.foreground.base}" }

        shape_and:                   { fg: "#${p.foreground.base}" attr: b }
        shape_binary:                "#${p.dim}"
        shape_block:                 "#${p.dim}"
        shape_bool:                  "#${p.foreground.variant}"
        shape_custom:                "#${p.foreground.base}"
        shape_datetime:              "#${p.foreground.variant}"
        shape_directory:             "#${p.accent.base}"
        shape_external:              { fg: "#${t.ansi.warn}" }
        shape_external_resolved:     { fg: "#${t.ansi.success}" attr: b }
        shape_externalarg:           "#${p.foreground.base}"
        shape_filepath:              "#${p.foreground.base}"
        shape_flag:                  { fg: "#${p.accent.base}" attr: b }
        shape_float:                 "#${p.foreground.base}"
        shape_garbage:               { fg: "#${t.ansi.error}" attr: b }
        shape_globpattern:           "#${t.ansi.info}"
        shape_int:                   "#${p.foreground.base}"
        shape_internalcall:          { fg: "#${p.foreground.variant}" attr: b }
        shape_keyword:               { fg: "#${p.foreground.base}" attr: b }
        shape_list:                  "#${p.dim}"
        shape_literal:               "#${p.foreground.base}"
        shape_match_pattern:         "#${p.foreground.base}"
        shape_matching_brackets:     { attr: u }
        shape_nothing:               "#${p.dim}"
        shape_operator:              "#${p.accent.base}"
        shape_or:                    { fg: "#${p.foreground.base}" attr: b }
        shape_pipe:                  { fg: "#${p.accent.base}" attr: b }
        shape_range:                 "#${p.foreground.base}"
        shape_record:                "#${p.dim}"
        shape_redirection:           { fg: "#${p.accent.base}" attr: b }
        shape_signature:             "#${p.foreground.variant}"
        shape_string:                "#${p.dim}"
        shape_string_interpolation:  "#${p.foreground.variant}"
        shape_table:                 "#${p.dim}"
        shape_variable:              "#${p.foreground.variant}"
        shape_vardecl:               "#${p.foreground.variant}"
        shape_raw_string:            "#${p.dim}"
    }

    def ls-entry [selector: string, hex: string, --bold, --underline] {
        let h = ($hex | str replace "#" "")
        let r = ($h | str substring 0..<2 | into int -r 16)
        let g = ($h | str substring 2..<4 | into int -r 16)
        let b = ($h | str substring 4..<6 | into int -r 16)
        let color = $"38;2;($r);($g);($b)"
        let attrs = (if $bold { ["1"] } else { [] })
            | append (if $underline { ["4"] } else { [] })
        let style = if ($attrs | is-empty) {
            $color
        } else {
            $"($attrs | str join ';');($color)"
        }
        $"($selector)=($style)"
    }

    let _fg = "#${p.foreground.base}"
    let _bright = "#${p.foreground.variant}"
    let _subtle = "#${p.accent.base}"
    let _accent = "#${p.accent.base}"
    let _muted = "#${p.dim}"
    let _comment = "#${p.dim}"
    let _success = "#${t.ansi.success}"
    let _warning = "#${t.ansi.warn}"
    let _error = "#${t.ansi.error}"
    let _blue = "#${p.surface.base}"
    let _cyan = "#${p.foreground.base}"
    let _magenta = "#${p.accent.variant}"

    $env.LS_COLORS = [
        "rs=0"
        (ls-entry di $_bright --bold)
        (ls-entry ln $_magenta)
        (ls-entry ex $_success --bold)
        (ls-entry or $_error)
        (ls-entry fi $_fg)
        (ls-entry "*.tar" $_warning)
        (ls-entry "*.gz" $_warning)
        (ls-entry "*.zip" $_warning)
    ] | str join ':'
  '';
in
[
  {
    path = "domains/shell/nushell/config/colors.nu";
    text = colorsText;
    checks = [
      (requireInfix colorsText "shape_garbage:               { fg: \"#${t.ansi.error}\""
        "nushell shape_garbage should render ${themeName} ansi.error"
      )
      (requireInfix colorsText "shape_globpattern:           \"#${t.ansi.info}\""
        "nushell shape_globpattern should render ${themeName} ansi.info"
      )
      (require (t.ansi.error != t.ansi.info) "nushell semantic ansi.error and ansi.info must differ in ${themeName}")
    ];
  }
]
