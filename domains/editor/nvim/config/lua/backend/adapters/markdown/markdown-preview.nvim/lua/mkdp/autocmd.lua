local M = {}

function M.init()
  local bufnr = vim.fn.bufnr("%")
  local augroup_name = "MKDP_REFRESH_INIT" .. bufnr
  local group = vim.api.nvim_create_augroup(augroup_name, { clear = true })

  if vim.g.mkdp_refresh_slow then
    vim.api.nvim_create_autocmd({ "CursorHold", "BufWrite", "InsertLeave" }, {
      group = group,
      buffer = bufnr,
      callback = function()
        require("mkdp.rpc").preview_refresh()
      end,
    })
  else
    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "CursorMoved", "CursorMovedI" }, {
      group = group,
      buffer = bufnr,
      callback = function()
        require("mkdp.rpc").preview_refresh()
      end,
    })
  end

  if vim.g.mkdp_auto_close then
    vim.api.nvim_create_autocmd("BufHidden", {
      group = group,
      buffer = bufnr,
      callback = function()
        require("mkdp.rpc").preview_close()
      end,
    })
  end

  vim.api.nvim_create_autocmd("VimLeave", {
    group = group,
    pattern = "*",
    callback = function()
      require("mkdp.rpc").stop_server()
    end,
  })
end

function M.clear_buf()
  local augroup_name = "MKDP_REFRESH_INIT" .. vim.fn.bufnr("%")
  pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
end

return M
