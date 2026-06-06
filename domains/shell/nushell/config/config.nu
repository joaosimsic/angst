$env.config = {
    show_banner: false

    edit_mode: vi
    cursor_shape: {
        vi_insert: line
        vi_normal: block
    }

    history: {
        max_size: 10000
        sync_on_enter: true
        file_format: "sqlite"
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

    hooks: {
        pre_prompt: [
            { ||
                do -i { ^amber grave reattach }
            }
        ]
        pre_execution: []
        env_change: {}
    }

    keybindings: [
        {
            name: clear_screen
            modifier: control
            keycode: char_l
            mode: [emacs, vi_normal, vi_insert]
            event: { send: clearscreen }
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
        {
            name: zellij_nav_left
            modifier: alt
            keycode: char_h
            mode: [emacs, vi_normal, vi_insert]
            event: { send: executehostcommand, cmd: "zellij action move-focus left" }
        }
        {
            name: zellij_nav_down
            modifier: alt
            keycode: char_j
            mode: [emacs, vi_normal, vi_insert]
            event: { send: executehostcommand, cmd: "zellij action move-focus down" }
        }
        {
            name: zellij_nav_up
            modifier: alt
            keycode: char_k
            mode: [emacs, vi_normal, vi_insert]
            event: { send: executehostcommand, cmd: "zellij action move-focus up" }
        }
        {
            name: zellij_nav_right
            modifier: alt
            keycode: char_l
            mode: [emacs, vi_normal, vi_insert]
            event: { send: executehostcommand, cmd: "zellij action move-focus right" }
        }
        {
            name: grave_session_selector
            modifier: control
            keycode: char_g
            mode: [emacs, vi_normal, vi_insert]
            event: { send: executehostcommand, cmd: "amber grave" }
        }
    ]
}

source colors.nu

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

alias nrs = sudo nixos-rebuild switch --flake .
alias nrb = sudo nixos-rebuild boot --flake .
alias nrt = sudo nixos-rebuild test --flake .

def --env mkcd [dir: string] {
    mkdir $dir
    cd $dir
}

def ff [pattern: string] {
    glob $"**/*($pattern)*"
}

def rg-files [pattern: string, --ext: string = ""] {
    if $ext == "" {
        ^rg -l $pattern
    } else {
        ^rg -l --glob $"*.($ext)" $pattern
    }
}
