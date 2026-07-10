$env.config.color_config = {
    separator:                   "#4e5166"
    leading_trailing_space_bg:   { attr: n }
    header:                      { fg: "#195466" attr: b }
    empty:                       "#4e5166"
    bool:                        "#99d1ce"
    int:                         "#195466"
    filesize:                    "#195466"
    duration:                    "#195466"
    date:                        "#99d1ce"
    range:                       "#195466"
    float:                       "#195466"
    string:                      "#195466"
    nothing:                     "#4e5166"
    binary:                      "#4e5166"
    cell_path:                   "#99d1ce"
    row_index:                   { fg: "#4e5166" attr: b }
    record:                      "#195466"
    list:                        "#195466"
    block:                       "#195466"
    hints:                       "#4e5166"
    search_result:               { fg: "#0c1014" bg: "#195466" }

    shape_and:                   { fg: "#195466" attr: b }
    shape_binary:                "#4e5166"
    shape_block:                 "#4e5166"
    shape_bool:                  "#99d1ce"
    shape_custom:                "#195466"
    shape_datetime:              "#99d1ce"
    shape_directory:             "#c23127"
    shape_external:              { fg: "#df9f28" }
    shape_external_resolved:     { fg: "#6e9643" attr: b }
    shape_externalarg:           "#195466"
    shape_filepath:              "#195466"
    shape_flag:                  { fg: "#c23127" attr: b }
    shape_float:                 "#195466"
    shape_garbage:               { fg: "#d9534f" attr: b }
    shape_globpattern:           "#5f9ea0"
    shape_int:                   "#195466"
    shape_internalcall:          { fg: "#99d1ce" attr: b }
    shape_keyword:               { fg: "#195466" attr: b }
    shape_list:                  "#4e5166"
    shape_literal:               "#195466"
    shape_match_pattern:         "#195466"
    shape_matching_brackets:     { attr: u }
    shape_nothing:               "#4e5166"
    shape_operator:              "#c23127"
    shape_or:                    { fg: "#195466" attr: b }
    shape_pipe:                  { fg: "#c23127" attr: b }
    shape_range:                 "#195466"
    shape_record:                "#4e5166"
    shape_redirection:           { fg: "#c23127" attr: b }
    shape_signature:             "#99d1ce"
    shape_string:                "#4e5166"
    shape_string_interpolation:  "#99d1ce"
    shape_table:                 "#4e5166"
    shape_variable:              "#99d1ce"
    shape_vardecl:               "#99d1ce"
    shape_raw_string:            "#4e5166"
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

let _fg = "#195466"
let _bright = "#99d1ce"
let _subtle = "#c23127"
let _accent = "#c23127"
let _muted = "#4e5166"
let _comment = "#4e5166"
let _success = "#6e9643"
let _warning = "#df9f28"
let _error = "#d9534f"
let _blue = "#33859e"
let _cyan = "#195466"
let _magenta = "#edb443"

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

