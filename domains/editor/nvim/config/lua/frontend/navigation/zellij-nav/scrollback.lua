local highlight = require("frontend.navigation.zellij-nav.highlight")

local M = {}

function M.setup()
    vim.api.nvim_create_autocmd("BufRead", {
        group = vim.api.nvim_create_augroup("zellij_scrollback", { clear = true }),
        pattern = "*.dump",
        callback = function(ev)
            vim.bo[ev.buf].filetype = "terminal-output"
            highlight.apply(ev.buf)
        end,
    })

    vim.api.nvim_create_user_command("ZellijScrollback", function()
        vim.g.zellij_scrollback = true
        local buf = vim.api.nvim_get_current_buf()
        vim.bo[buf].filetype = "terminal-output"
        highlight.apply(buf)
    end, {})
end

return M
