$env.config.color_config = {
    separator:                   "#484f58"
    leading_trailing_space_bg:   { attr: n }
    header:                      { fg: "#bc8cff" attr: b }
    empty:                       "#484f58"
    bool:                        "#b1bac4"
    int:                         "#bc8cff"
    filesize:                    "#bc8cff"
    duration:                    "#bc8cff"
    date:                        "#b1bac4"
    range:                       "#bc8cff"
    float:                       "#bc8cff"
    string:                      "#bc8cff"
    nothing:                     "#484f58"
    binary:                      "#484f58"
    cell_path:                   "#b1bac4"
    row_index:                   { fg: "#484f58" attr: b }
    record:                      "#bc8cff"
    list:                        "#bc8cff"
    block:                       "#bc8cff"
    hints:                       "#484f58"
    search_result:               { fg: "#010409" bg: "#bc8cff" }

    shape_and:                   { fg: "#bc8cff" attr: b }
    shape_binary:                "#484f58"
    shape_block:                 "#484f58"
    shape_bool:                  "#b1bac4"
    shape_custom:                "#bc8cff"
    shape_datetime:              "#b1bac4"
    shape_directory:             "#ff7b72"
    shape_external:              { fg: "#f2b134" }
    shape_external_resolved:     { fg: "#3fb950" attr: b }
    shape_externalarg:           "#bc8cff"
    shape_filepath:              "#bc8cff"
    shape_flag:                  { fg: "#ff7b72" attr: b }
    shape_float:                 "#bc8cff"
    shape_garbage:               { fg: "#ff6e6e" attr: b }
    shape_globpattern:           "#58a6ff"
    shape_int:                   "#bc8cff"
    shape_internalcall:          { fg: "#b1bac4" attr: b }
    shape_keyword:               { fg: "#bc8cff" attr: b }
    shape_list:                  "#484f58"
    shape_literal:               "#bc8cff"
    shape_match_pattern:         "#bc8cff"
    shape_matching_brackets:     { attr: u }
    shape_nothing:               "#484f58"
    shape_operator:              "#ff7b72"
    shape_or:                    { fg: "#bc8cff" attr: b }
    shape_pipe:                  { fg: "#ff7b72" attr: b }
    shape_range:                 "#bc8cff"
    shape_record:                "#484f58"
    shape_redirection:           { fg: "#ff7b72" attr: b }
    shape_signature:             "#b1bac4"
    shape_string:                "#484f58"
    shape_string_interpolation:  "#b1bac4"
    shape_table:                 "#484f58"
    shape_variable:              "#b1bac4"
    shape_vardecl:               "#b1bac4"
    shape_raw_string:            "#484f58"
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

let _fg = "#bc8cff"
let _bright = "#b1bac4"
let _subtle = "#ff7b72"
let _accent = "#ff7b72"
let _muted = "#484f58"
let _comment = "#484f58"
let _success = "#3fb950"
let _warning = "#f2b134"
let _error = "#ff6e6e"
let _blue = "#3fb950"
let _cyan = "#bc8cff"
let _magenta = "#d29922"

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

