$env.config.color_config = {
    separator:                   "#c7c7c7"
    leading_trailing_space_bg:   { attr: n }
    header:                      { fg: "#c2c2b0" attr: b }
    empty:                       "#685742"
    bool:                        "#d7c483"
    int:                         "#c2c2b0"
    filesize:                    "#c2c2b0"
    duration:                    "#c2c2b0"
    date:                        "#d7c483"
    range:                       "#c2c2b0"
    float:                       "#c2c2b0"
    string:                      "#c2c2b0"
    nothing:                     "#685742"
    binary:                      "#685742"
    cell_path:                   "#d7c483"
    row_index:                   { fg: "#685742" attr: b }
    record:                      "#c2c2b0"
    list:                        "#c2c2b0"
    block:                       "#c2c2b0"
    hints:                       "#c7c7c7"
    search_result:               { fg: "#222222" bg: "#c2c2b0" }

    shape_and:                   { fg: "#c2c2b0" attr: b }
    shape_binary:                "#685742"
    shape_block:                 "#685742"
    shape_bool:                  "#d7c483"
    shape_custom:                "#c2c2b0"
    shape_datetime:              "#d7c483"
    shape_directory:             "#d7c483"
    shape_external:              { fg: "#685742" }
    shape_external_resolved:     { fg: "#5f875f" attr: b }
    shape_externalarg:           "#c2c2b0"
    shape_filepath:              "#c2c2b0"
    shape_flag:                  { fg: "#d7c483" attr: b }
    shape_float:                 "#c2c2b0"
    shape_garbage:               { fg: "#685742" attr: b }
    shape_globpattern:           "#c9a554"
    shape_int:                   "#c2c2b0"
    shape_internalcall:          { fg: "#d7c483" attr: b }
    shape_keyword:               { fg: "#c2c2b0" attr: b }
    shape_list:                  "#685742"
    shape_literal:               "#c2c2b0"
    shape_match_pattern:         "#c2c2b0"
    shape_matching_brackets:     { attr: u }
    shape_nothing:               "#685742"
    shape_operator:              "#e5c47b"
    shape_or:                    { fg: "#c2c2b0" attr: b }
    shape_pipe:                  { fg: "#e5c47b" attr: b }
    shape_range:                 "#c2c2b0"
    shape_record:                "#685742"
    shape_redirection:           { fg: "#e5c47b" attr: b }
    shape_signature:             "#d7c483"
    shape_string:                "#685742"
    shape_string_interpolation:  "#d7c483"
    shape_table:                 "#685742"
    shape_variable:              "#d7c483"
    shape_vardecl:               "#d7c483"
    shape_raw_string:            "#685742"
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
let _bright = "#d7c483"
let _subtle = "#e5c47b"
let _accent = "#d7c483"
let _muted = "#c7c7c7"
let _comment = "#685742"
let _success = "#5f875f"
let _warning = "#b36d43"
let _error = "#685742"
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
