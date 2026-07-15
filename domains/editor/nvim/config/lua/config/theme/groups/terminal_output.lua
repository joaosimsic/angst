local palette = require("config.theme.palette").get()
local p = palette.palette
local a = palette.ansi

local M = {}

M.get = function()
    return {
        TermUser = { fg = a.info, bold = true },
        TermPath = { fg = p.accent.base, bold = true },
        TermGitBranch = { fg = a.info },
        TermGitStatus = { fg = a.warn },
        TermCommand = { fg = p.foreground.variant },
        TermNixShell = { fg = p.foreground.variant },
        TermError = { fg = a.error, bold = true },
        TermSignal = { fg = p.dim },
    }
end

return M
