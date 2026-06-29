$env.config = {
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
        path: ($env.XDG_DATA_HOME | path join "nushell/history.sqlite3")
    }

    completions: {
        case_sensitive: false
        quick: true
        partial: true
        algorithm: "fuzzy"
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

alias z = zellij

alias c = clear
alias q = exit
alias reload = exec nu
