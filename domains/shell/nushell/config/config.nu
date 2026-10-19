$env.config = ($env.config | merge {
    show_banner: false

    edit_mode: vi

    cursor_shape: {
        vi_insert: block
        vi_normal: block
    }

    history: {
        max_size: 10000
        sync_on_enter: true
        file_format: "sqlite"
        path: ($nu.data-dir | path join "history.sqlite3")
    }

    completions: {
        case_sensitive: false
        quick: true
        partial: true
        algorithm: "fuzzy"

        external: {
            enable: true
            completer: {|spans|
                if ($spans | length) == 0 {
                    return []
                }
                if ($spans | first) == "just" {
                    just-completions
                } else {
                    load-env {
                        CARAPACE_SHELL_BUILTINS: (help commands | where category != "" | get name | each { split row " " | first } | uniq | str join "\n")
                        CARAPACE_SHELL_FUNCTIONS: (help commands | where category == "" | get name | each { split row " " | first } | uniq | str join "\n")
                    }
                    let expanded_alias = (scope aliases | where name == $spans.0 | $in.0?.expansion?)
                    let spans = (
                        if $expanded_alias != null {
                            $spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
                        } else {
                            $spans | skip 1 | prepend ($spans.0)
                        }
                    )
                    ^carapace $spans.0 nushell ...$spans | from json
                }
            }
        }
    }

    table: {
        mode: rounded
        index_mode: auto
        show_empty: true
        padding: { left: 1, right: 1 }
        trim: {
            methodology: wrapping
            wrapping_try_keep_words: true
        }
        header_on_separator: false
    }

    error_style: "fancy"

    highlight_resolved_externals: true

    hooks: {
        env_change: {
            PWD: [
                { || try { direnv export json | from json | load-env } catch { } }
            ]
        }
    }

    keybindings: [
        {
            name: ctrl_c_to_normal
            modifier: control
            keycode: char_c
            mode: [vi_insert]
            event: { send: vichangemode, mode: normal }
        }
        {
            name: history_search
            modifier: control
            keycode: char_r
            mode: [emacs, vi_normal, vi_insert]
            event: { send: searchhistory }
        }
        {
            name: complete_hint
            modifier: control
            keycode: char_f
            mode: [emacs, vi_normal, vi_insert]
            event: { send: historyhintcomplete }
        }
    ]
}
)

source $"($nu.default-config-dir)/colors.nu"

alias .. = cd ..
alias ... = cd ../..
alias .... = cd ../../..

alias ll = ls -l
alias la = ls -a
alias lla = ls -la

alias g = git
alias gs = git status
alias ga = git add
alias gc = git commit
alias gp = git push
alias gl = git pull
alias gd = git diff
alias gco = git checkout
alias gb = git branch
alias glog = git log --oneline --graph

alias v = nvim
alias vi = nvim
alias vim = nvim

alias hms = hm-switch

alias z = zellij

alias c = clear
alias q = exit
alias reload = exec nu

def --wrapped agent [...rest] {
    if (which cursor | length) > 0 {
        ^cursor agent ...$rest
    } else if (which cursor-agent | length) > 0 {
        ^cursor-agent ...$rest
    } else {
        error make { msg: "cursor-agent is not installed" }
    }
}



def just-completions [] {
    try { ^just --summary } catch { return [] }
    | split row ' '
    | str trim
    | where { |r| $r != "" }
    | each { |r| { value: $r, display: $r } }
}


