return {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {
        dir = vim.fn.stdpath("state") .. "/sessions/",
        need = 1,
        branch = true,
    },
    init = function()
        vim.api.nvim_create_autocmd("VimEnter", {
            group = vim.api.nvim_create_augroup("restore_session", { clear = true }),
            callback = function()
                if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
                    require("persistence").load()
                end
            end,
            nested = true,
        })
    end,
    keys = {
        {
            "<leader>qs",
            function()
                require("persistence").load()
            end,
            desc = "Restore session for cwd",
        },
        {
            "<leader>qS",
            function()
                require("persistence").select()
            end,
            desc = "Select session to restore",
        },
        {
            "<leader>ql",
            function()
                require("persistence").load({ last = true })
            end,
            desc = "Restore last session",
        },
        {
            "<leader>qd",
            function()
                require("persistence").stop()
            end,
            desc = "Stop session recording",
        },
    },
}
