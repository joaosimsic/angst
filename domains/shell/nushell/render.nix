{
  themesLib,
  themeName,
  checkHelpers,
  ...
}:

let
  t = themesLib.get themeName;
  inherit (checkHelpers) requireInfix require;

  colorsText = ''
    $env.config.color_config = {
        separator:                   "#${t.MUTED}"
        leading_trailing_space_bg:   { attr: n }
        header:                      { fg: "#${t.FG}" attr: b }
        empty:                       "#${t.COMMENT}"
        bool:                        "#${t.BRIGHT}"
        int:                         "#${t.FG}"
        filesize:                    "#${t.FG}"
        duration:                    "#${t.FG}"
        date:                        "#${t.BRIGHT}"
        range:                       "#${t.FG}"
        float:                       "#${t.FG}"
        string:                      "#${t.FG}"
        nothing:                     "#${t.COMMENT}"
        binary:                      "#${t.COMMENT}"
        cell_path:                   "#${t.BRIGHT}"
        row_index:                   { fg: "#${t.COMMENT}" attr: b }
        record:                      "#${t.FG}"
        list:                        "#${t.FG}"
        block:                       "#${t.FG}"
        hints:                       "#${t.MUTED}"
        search_result:               { fg: "#${t.BG}" bg: "#${t.FG}" }

        shape_and:                   { fg: "#${t.FG}" attr: b }
        shape_binary:                "#${t.COMMENT}"
        shape_block:                 "#${t.COMMENT}"
        shape_bool:                  "#${t.BRIGHT}"
        shape_custom:                "#${t.FG}"
        shape_datetime:              "#${t.BRIGHT}"
        shape_directory:             "#${t.ACCENT}"
        shape_external:              { fg: "#${t.WARNING}" }
        shape_external_resolved:     { fg: "#${t.SUCCESS}" attr: b }
        shape_externalarg:           "#${t.FG}"
        shape_filepath:              "#${t.FG}"
        shape_flag:                  { fg: "#${t.ACCENT}" attr: b }
        shape_float:                 "#${t.FG}"
        shape_garbage:               { fg: "#${t.ERROR}" attr: b }
        shape_globpattern:           "#${t.INFO}"
        shape_int:                   "#${t.FG}"
        shape_internalcall:          { fg: "#${t.BRIGHT}" attr: b }
        shape_keyword:               { fg: "#${t.FG}" attr: b }
        shape_list:                  "#${t.COMMENT}"
        shape_literal:               "#${t.FG}"
        shape_match_pattern:         "#${t.FG}"
        shape_matching_brackets:     { attr: u }
        shape_nothing:               "#${t.COMMENT}"
        shape_operator:              "#${t.SUBTLE}"
        shape_or:                    { fg: "#${t.FG}" attr: b }
        shape_pipe:                  { fg: "#${t.SUBTLE}" attr: b }
        shape_range:                 "#${t.FG}"
        shape_record:                "#${t.COMMENT}"
        shape_redirection:           { fg: "#${t.SUBTLE}" attr: b }
        shape_signature:             "#${t.BRIGHT}"
        shape_string:                "#${t.COMMENT}"
        shape_string_interpolation:  "#${t.BRIGHT}"
        shape_table:                 "#${t.COMMENT}"
        shape_variable:              "#${t.BRIGHT}"
        shape_vardecl:               "#${t.BRIGHT}"
        shape_raw_string:            "#${t.COMMENT}"
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

    let _fg = "#${t.FG}"
    let _bright = "#${t.BRIGHT}"
    let _subtle = "#${t.SUBTLE}"
    let _accent = "#${t.ACCENT}"
    let _muted = "#${t.MUTED}"
    let _comment = "#${t.COMMENT}"
    let _success = "#${t.SUCCESS}"
    let _warning = "#${t.WARNING}"
    let _error = "#${t.ERROR}"
    let _blue = "#${t.BLUE}"
    let _cyan = "#${t.CYAN}"
    let _magenta = "#${t.MAGENTA}"

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
      (requireInfix colorsText "shape_garbage:               { fg: \"#${t.ERROR}\""
        "nushell shape_garbage should render ${themeName} ERROR"
      )
      (requireInfix colorsText "shape_globpattern:           \"#${t.INFO}\""
        "nushell shape_globpattern should render ${themeName} INFO"
      )
      (require (t.ERROR != t.INFO) "nushell semantic ERROR and INFO must differ in ${themeName}")
    ];
  }
]
