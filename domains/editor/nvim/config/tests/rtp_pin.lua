-- Runs inside the plenary test child process: make the working tree the first
-- config source so a rendered copy at ~/.config/nvim never shadows it.
local source = debug.getinfo(1, "S").source:sub(2)
local config_root = vim.fn.fnamemodify(source, ":p:h:h")

vim.opt.rtp:remove(vim.fn.expand("~/.config/nvim"))
vim.opt.rtp:prepend(config_root)
