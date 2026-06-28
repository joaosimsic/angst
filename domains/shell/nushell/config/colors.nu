$env.config.color_config = {
    separator:                   "#c7c7c7"
    leading_trailing_space_bg:   { attr: n }
    header:                      { fg: "#c2c2b0" attr: b }
    empty:                       "#6e6e5c"
    bool:                        "#eeeeee"
    int:                         "#c2c2b0"
    filesize:                    "#c2c2b0"
    duration:                    "#c2c2b0"
    date:                        "#eeeeee"
    range:                       "#c2c2b0"
    float:                       "#c2c2b0"
    string:                      "#c2c2b0"
    nothing:                     "#6e6e5c"
    binary:                      "#6e6e5c"
    cell_path:                   "#eeeeee"
    row_index:                   { fg: "#6e6e5c" attr: b }
    record:                      "#c2c2b0"
    list:                        "#c2c2b0"
    block:                       "#c2c2b0"
    hints:                       "#c7c7c7"
    search_result:               { fg: "#222222" bg: "#c2c2b0" }

    shape_and:                   { fg: "#c2c2b0" attr: b }
    shape_binary:                "#6e6e5c"
    shape_block:                 "#6e6e5c"
    shape_bool:                  "#eeeeee"
    shape_custom:                "#c2c2b0"
    shape_datetime:              "#eeeeee"
    shape_directory:             "#c2c2b0"
    shape_external:              { fg: "#b84a4a" }
    shape_external_resolved:     { fg: "#608f60" attr: b }
    shape_externalarg:           "#c2c2b0"
    shape_filepath:              "#c2c2b0"
    shape_flag:                  { fg: "#eeeeee" attr: b }
    shape_float:                 "#c2c2b0"
    shape_garbage:               { fg: "#b84a4a" attr: b }
    shape_globpattern:           "#6290a0"
    shape_int:                   "#c2c2b0"
    shape_internalcall:          { fg: "#eeeeee" attr: b }
    shape_keyword:               { fg: "#c2c2b0" attr: b }
    shape_list:                  "#6e6e5c"
    shape_literal:               "#c2c2b0"
    shape_match_pattern:         "#c2c2b0"
    shape_matching_brackets:     { attr: u }
    shape_nothing:               "#6e6e5c"
    shape_operator:              "#8c8c7a"
    shape_or:                    { fg: "#c2c2b0" attr: b }
    shape_pipe:                  { fg: "#8c8c7a" attr: b }
    shape_range:                 "#c2c2b0"
    shape_record:                "#6e6e5c"
    shape_redirection:           { fg: "#8c8c7a" attr: b }
    shape_signature:             "#eeeeee"
    shape_string:                "#6e6e5c"
    shape_string_interpolation:  "#eeeeee"
    shape_table:                 "#6e6e5c"
    shape_variable:              "#eeeeee"
    shape_vardecl:               "#eeeeee"
    shape_raw_string:            "#6e6e5c"
}

def ls-entry [selector: string, hex: string, --bold, --underline] {
    let h = ($hex | str replace '#' '')
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

let _fg = "#c2c2b0"
let _bright = "#eeeeee"
let _subtle = "#8c8c7a"
let _accent = "#d4c8a8"
let _muted = "#c7c7c7"
let _comment = "#6e6e5c"
let _success = "#608f60"
let _warning = "#c4904a"
let _error = "#b84a4a"
let _blue = "#6290a0"
let _cyan = "#5faa8e"
let _magenta = "#a07aaa"

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
