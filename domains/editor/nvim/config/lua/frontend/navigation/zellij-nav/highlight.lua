local ns = vim.api.nvim_create_namespace("terminal_output")

local M = {}

---@param buf integer
function M.apply(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    for i, line in ipairs(lines) do
        local row = i - 1
        local len = #line
        if len == 0 then goto continue end

        if line:find("^[a-z_]+: command not found")
            or line:find("^zsh:")
            or line:find("^bash:")
            or line:find("^nu:")
        then
            vim.api.nvim_buf_add_highlight(buf, ns, "TermError", row, 0, len)
            goto continue
        end

        if line:find("^%^[CDZ\\]") then
            vim.api.nvim_buf_add_highlight(buf, ns, "TermSignal", row, 0, len)
            goto continue
        end

        if line:match("^[%a_][%w_]*") and (line:find("~/") or line:find(" %[")) then
            local function hilight(pattern, group)
                local s, e = line:find(pattern)
                if s then
                    vim.api.nvim_buf_add_highlight(buf, ns, group, row, s - 1, e)
                    return e
                end
            end

            local user_end = line:find("%s")
            if user_end then
                vim.api.nvim_buf_add_highlight(buf, ns, "TermUser", row, 0, user_end - 1)
            end

            local last_end = 0
            local pe

            pe = hilight("~[%w%._%-/]*", "TermPath")
            if pe then last_end = math.max(last_end, pe) end

            pe = hilight("%*[%w%._%-/]+", "TermGitBranch")
            if pe then last_end = math.max(last_end, pe) end

            pe = hilight("%[[%+%-%?!%%%~%*rx]+%]", "TermGitStatus")
            if pe then last_end = math.max(last_end, pe) end

            if last_end > 0 and last_end < len then
                vim.api.nvim_buf_add_highlight(buf, ns, "TermCommand", row, last_end, len)
            end

            goto continue
        end

        ::continue::
    end
end

return M
