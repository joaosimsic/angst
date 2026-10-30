local source = debug.getinfo(1, "S").source:sub(2)
local bootstrap = vim.fn.fnamemodify(source, ":p:h:h") .. "/bootstrap.lua"
dofile(bootstrap)
