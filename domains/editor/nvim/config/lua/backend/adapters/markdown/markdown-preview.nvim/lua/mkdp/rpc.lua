local M = {}

local source = debug.getinfo(1, "S").source:gsub("^@", "")
local root_dir = vim.fn.fnamemodify(source, ":p:h:h:h")

local channel_id = -1
local intentional_stop = false

local function on_stdout(_, msgs)
  if msgs and #msgs > 0 then
    vim.schedule(function()
      require("mkdp").echo_messages("Error", msgs)
    end)
  end
end

local function on_stderr(_, msgs)
  if msgs and #msgs > 0 then
    vim.schedule(function()
      require("mkdp").echo_messages("Error", msgs)
    end)
  end
end

local function on_exit(_, code)
  channel_id = -1
  vim.g.mkdp_clients_active = 0
  if not intentional_stop then
    vim.schedule(function()
      vim.api.nvim_exec_autocmds("User", { pattern = "MkdpPreviewStop" })
    end)
  end
  intentional_stop = false
end

function M.get_server_status()
  if channel_id == -1 then
    return -1
  end
  return 1
end

function M.start_server()
  local server_script = root_dir .. "/app/bin/markdown-preview-" .. require("mkdp").get_platform()

  local cmd
  if vim.fn.executable(server_script) == 1 then
    cmd = { server_script, "--path", root_dir .. "/app/server.js" }
  elseif vim.fn.executable("bun") == 1 then
    cmd = { "bun", root_dir .. "/app/index.js", "--path", root_dir .. "/app/server.js" }
  else
    require("mkdp").echo_messages("Error", { "[markdown-preview.nvim]: Pre build and bun is not found" })
    return
  end

  channel_id = vim.fn.jobstart(cmd, {
    rpc = true,
    on_stdout = on_stdout,
    on_stderr = on_stderr,
    on_exit = on_exit,
  })
end

function M.stop_server()
  if channel_id ~= -1 then
    intentional_stop = true
    pcall(vim.fn.rpcrequest, channel_id, "close_all_pages")
    pcall(vim.fn.jobstop, channel_id)
  end
  channel_id = -1
  vim.b.MarkdownPreviewToggleBool = 0
end

function M.preview_refresh()
  if channel_id ~= -1 then
    pcall(vim.fn.rpcnotify, channel_id, "refresh_content", { bufnr = vim.fn.bufnr("%") })
  end
end

function M.preview_close()
  if channel_id ~= -1 then
    pcall(vim.fn.rpcnotify, channel_id, "close_page", { bufnr = vim.fn.bufnr("%") })
  end
  vim.b.MarkdownPreviewToggleBool = 0
  require("mkdp.autocmd").clear_buf()
end

function M.open_browser()
  if channel_id ~= -1 then
    pcall(vim.fn.rpcnotify, channel_id, "open_browser", { bufnr = vim.fn.bufnr("%") })
  end
end

return M
