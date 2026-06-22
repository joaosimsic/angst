local Keybinder = require("common.Keybinder")
local fzf = require("fzf-lua")

local binder = Keybinder.new(nil, "FZF")

binder:nmap("<leader>ff", fzf.files, "Find files")
binder:nmap("<leader>fg", fzf.live_grep, "Live grep")
binder:nmap("<leader>fb", fzf.buffers, "Buffers")
binder:nmap("<leader>fo", fzf.oldfiles, "Recent files")
binder:nmap("<leader>fh", fzf.help_tags, "Help tags")

return {}
