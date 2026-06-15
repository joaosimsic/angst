$env.config.color_config = {
    separator:                   "#a6a69c"
    leading_trailing_space_bg:   { attr: n }
    header:                      { fg: "#c5c9c5" attr: b }
    empty:                       "#a292a3"
    bool:                        "#c8c093"
    int:                         "#c5c9c5"
    filesize:                    "#c5c9c5"
    duration:                    "#c5c9c5"
    date:                        "#c8c093"
    range:                       "#c5c9c5"
    float:                       "#c5c9c5"
    string:                      "#c5c9c5"
    nothing:                     "#a292a3"
    binary:                      "#a292a3"
    cell_path:                   "#c8c093"
    row_index:                   { fg: "#a292a3" attr: b }
    record:                      "#c5c9c5"
    list:                        "#c5c9c5"
    block:                       "#c5c9c5"
    hints:                       "#a6a69c"
    search_result:               { fg: "#181616" bg: "#c5c9c5" }

    shape_and:                   { fg: "#c5c9c5" attr: b }
    shape_binary:                "#a292a3"
    shape_block:                 "#a292a3"
    shape_bool:                  "#c8c093"
    shape_custom:                "#c5c9c5"
    shape_datetime:              "#c8c093"
    shape_directory:             "#c5c9c5"
    shape_external:              { fg: "#c4746e" }
    shape_external_resolved:     { fg: "#8a9a7b" attr: b }
    shape_externalarg:           "#c5c9c5"
    shape_filepath:              "#c5c9c5"
    shape_flag:                  { fg: "#c8c093" attr: b }
    shape_float:                 "#c5c9c5"
    shape_garbage:               { fg: "#c4746e" attr: b }
    shape_globpattern:           "#8ea4a2"
    shape_int:                   "#c5c9c5"
    shape_internalcall:          { fg: "#c8c093" attr: b }
    shape_keyword:               { fg: "#c5c9c5" attr: b }
    shape_list:                  "#a292a3"
    shape_literal:               "#c5c9c5"
    shape_match_pattern:         "#c5c9c5"
    shape_matching_brackets:     { attr: u }
    shape_nothing:               "#a292a3"
    shape_operator:              "#c5c9c5"
    shape_or:                    { fg: "#c5c9c5" attr: b }
    shape_pipe:                  { fg: "#c8c093" attr: b }
    shape_range:                 "#c5c9c5"
    shape_record:                "#a292a3"
    shape_redirection:           { fg: "#c8c093" attr: b }
    shape_signature:             "#c8c093"
    shape_string:                "#a292a3"
    shape_string_interpolation:  "#c8c093"
    shape_table:                 "#a292a3"
    shape_variable:              "#c8c093"
    shape_vardecl:               "#c8c093"
    shape_raw_string:            "#a292a3"
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

let _fg = "#c5c9c5"
let _bright = "#c8c093"
let _muted = "#a6a69c"
let _comment = "#a292a3"
let _success = "#8a9a7b"
let _warning = "#c4b28a"
let _error = "#c4746e"
let _blue = "#8ba4b0"
let _cyan = "#8ea4a2"
let _magenta = "#a292a3"

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
