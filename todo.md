# nvim

- [x] vim modes still appear on command prompt
- [x] refac config
- [x] test lsp, treesitter, etc...
- [x] fzf vim motions
- [x] autocmd for lspdetach
- [x] auto closing enter bug
- [x] paste and copy without overriding registers
- [x] break distance based either on tab space or formatters
- [x] leave yazi returns heirline in terminal mode
- [x] update scratch plugin to allow run compiler on it
- [ ] better git handling(neogit/diffview)
- [x] md handling(md-preview/render-md)
- [x] add file line length in heirline
- [x] fix render md badge and move through zellij
- [ ] add profiler, benchmark and assembly view for scratch plugin
- [x] move adapter to use new toolchain definitions
- [ ] spring idea, pull the string until reach a file, then release it to return to where u first pulled. a quick recall

# nu

- [x] set ":" to replace ">"
- [x] fix vim motions

# nix

- [x] add package managers to toolchains
- [x] use nixos-generate-config to set hardware

# toolchains

- [x] yaml
- [x] json formatter

# analyzer

- [ ] make dynamic scanning

# vm

- [x] dev shell vm bin doesnt get updated
- [x] deprecating vm scripts to let rust tool handles it
- [x] add a headless mode for launching the vm without gui
- [x] ci tests
- [x] static angst repo mounting
- [x] make vm run in a fixed terminal subprocess and dont outlive its parent
- [x] make mcp be run alongside the vm startup
- [x] when host mouse disabled, unable to leave the input grab of vm

# zellij

- [x] screen freeze when exit or close last pane
- [x] make ctrl j/k got to the first or last tab
- [ ] add ctrl m to go to the middle tab

# encryption

- [x] stardand way to encrypt files and dirs
- [x] validate projects and ftp pipelines

# miscellaneous

- [x] login screen
- [x] firefox
- [x] persistent and not persistent prints
- [x] notifications and add print notifications

# i3

- [x] mouse hide button and i3 shortcut
- [x] switch active and inactive ws number colors
- [x] better differentiate active and inactive windows
- [~] make windows/workspaces that have an update blink, so its better visually to know when do i need to callback to something
- [x] remove dark bg in memory section in status bar when memory > 20%
- [x] mute bind aware of running media just so it can stop them instead of only blindely muting the whole system
- [ ] lock desktop key that goes to ly or DM

# opencode

- [x] make add/remove diff lines be derived from ansi green/red and the bg colors
- [x] add gg and G binds to go to top and bottom of chat

# vial

- [ ] handle portuguese

# install

- [ ] generic host
- [ ] auto partition calamares disk
- [ ] heavy testing of auto partition
