$env.config.color_config = {
    separator:                   "#685742"
    leading_trailing_space_bg:   { attr: n }
    header:                      { fg: "#c9a554" attr: b }
    empty:                       "#685742"
    bool:                        "#d7c483"
    int:                         "#c9a554"
    filesize:                    "#c9a554"
    duration:                    "#c9a554"
    date:                        "#d7c483"
    range:                       "#c9a554"
    float:                       "#c9a554"
    string:                      "#c9a554"
    nothing:                     "#685742"
    binary:                      "#685742"
    cell_path:                   "#d7c483"
    row_index:                   { fg: "#685742" attr: b }
    record:                      "#c9a554"
    list:                        "#c9a554"
    block:                       "#c9a554"
    hints:                       "#685742"
    search_result:               { fg: "#272727" bg: "#c9a554" }

    shape_and:                   { fg: "#c9a554" attr: b }
    shape_binary:                "#685742"
    shape_block:                 "#685742"
    shape_bool:                  "#d7c483"
    shape_custom:                "#c9a554"
    shape_datetime:              "#d7c483"
    shape_directory:             "#b36d43"
    shape_external:              { fg: "#ffaa00" }
    shape_external_resolved:     { fg: "#00c851" attr: b }
    shape_externalarg:           "#c9a554"
    shape_filepath:              "#c9a554"
    shape_flag:                  { fg: "#b36d43" attr: b }
    shape_float:                 "#c9a554"
    shape_garbage:               { fg: "#ff3333" attr: b }
    shape_globpattern:           "#33b5e5"
    shape_int:                   "#c9a554"
    shape_internalcall:          { fg: "#d7c483" attr: b }
    shape_keyword:               { fg: "#c9a554" attr: b }
    shape_list:                  "#685742"
    shape_literal:               "#c9a554"
    shape_match_pattern:         "#c9a554"
    shape_matching_brackets:     { attr: u }
    shape_nothing:               "#685742"
    shape_operator:              "#b36d43"
    shape_or:                    { fg: "#c9a554" attr: b }
    shape_pipe:                  { fg: "#b36d43" attr: b }
    shape_range:                 "#c9a554"
    shape_record:                "#685742"
    shape_redirection:           { fg: "#b36d43" attr: b }
    shape_signature:             "#d7c483"
    shape_string:                "#685742"
    shape_string_interpolation:  "#d7c483"
    shape_table:                 "#685742"
    shape_variable:              "#d7c483"
    shape_vardecl:               "#d7c483"
    shape_raw_string:            "#685742"
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

let _fg = "#c9a554"
let _bright = "#d7c483"
let _subtle = "#b36d43"
let _accent = "#b36d43"
let _muted = "#685742"
let _comment = "#685742"
let _success = "#00c851"
let _warning = "#ffaa00"
let _error = "#ff3333"
let _blue = "#78824b"
let _cyan = "#c9a554"
let _magenta = "#bb7744"

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

