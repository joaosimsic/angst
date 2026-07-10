$env.config.color_config = {
    separator:                   "#597b75"
    leading_trailing_space_bg:   { attr: n }
    header:                      { fg: "#4d699b" attr: b }
    empty:                       "#597b75"
    bool:                        "#545464"
    int:                         "#4d699b"
    filesize:                    "#4d699b"
    duration:                    "#4d699b"
    date:                        "#545464"
    range:                       "#4d699b"
    float:                       "#4d699b"
    string:                      "#4d699b"
    nothing:                     "#597b75"
    binary:                      "#597b75"
    cell_path:                   "#545464"
    row_index:                   { fg: "#597b75" attr: b }
    record:                      "#4d699b"
    list:                        "#4d699b"
    block:                       "#4d699b"
    hints:                       "#597b75"
    search_result:               { fg: "#f2ecbc" bg: "#4d699b" }

    shape_and:                   { fg: "#4d699b" attr: b }
    shape_binary:                "#597b75"
    shape_block:                 "#597b75"
    shape_bool:                  "#545464"
    shape_custom:                "#4d699b"
    shape_datetime:              "#545464"
    shape_directory:             "#c84053"
    shape_external:              { fg: "#d9822b" }
    shape_external_resolved:     { fg: "#528c38" attr: b }
    shape_externalarg:           "#4d699b"
    shape_filepath:              "#4d699b"
    shape_flag:                  { fg: "#c84053" attr: b }
    shape_float:                 "#4d699b"
    shape_garbage:               { fg: "#d62839" attr: b }
    shape_globpattern:           "#2b5c8f"
    shape_int:                   "#4d699b"
    shape_internalcall:          { fg: "#545464" attr: b }
    shape_keyword:               { fg: "#4d699b" attr: b }
    shape_list:                  "#597b75"
    shape_literal:               "#4d699b"
    shape_match_pattern:         "#4d699b"
    shape_matching_brackets:     { attr: u }
    shape_nothing:               "#597b75"
    shape_operator:              "#c84053"
    shape_or:                    { fg: "#4d699b" attr: b }
    shape_pipe:                  { fg: "#c84053" attr: b }
    shape_range:                 "#4d699b"
    shape_record:                "#597b75"
    shape_redirection:           { fg: "#c84053" attr: b }
    shape_signature:             "#545464"
    shape_string:                "#597b75"
    shape_string_interpolation:  "#545464"
    shape_table:                 "#597b75"
    shape_variable:              "#545464"
    shape_vardecl:               "#545464"
    shape_raw_string:            "#597b75"
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

let _fg = "#4d699b"
let _bright = "#545464"
let _subtle = "#c84053"
let _accent = "#c84053"
let _muted = "#597b75"
let _comment = "#597b75"
let _success = "#528c38"
let _warning = "#d9822b"
let _error = "#d62839"
let _blue = "#77713f"
let _cyan = "#4d699b"
let _magenta = "#b35b79"

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

