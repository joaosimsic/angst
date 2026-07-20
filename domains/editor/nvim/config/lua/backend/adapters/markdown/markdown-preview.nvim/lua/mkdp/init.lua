local rpc = require("mkdp.rpc")
local autocmd = require("mkdp.autocmd")

local M = {}

local try_id = nil

local function try_open_preview_page()
  local status = rpc.get_server_status()
  if status ~= 1 then
    try_id = nil
    rpc.stop_server()
    rpc.start_server()
  end
end

function M.get_platform()
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    return "win"
  elseif vim.fn.has("mac") == 1 then
    if vim.fn.system("arch"):match("arm64") then
      return "macos-arm64"
    end
    return "macos"
  end
  return "linux"
end

function M.echo_messages(hl, msgs)
  if not msgs or #msgs == 0 then
    return
  end
  vim.cmd(("echohl %s"):format(hl))
  if type(msgs) == "string" then
    vim.cmd(("echomsg %s"):format(vim.fn.string(msgs)))
  else
    for _, msg in ipairs(msgs) do
      vim.cmd(("echomsg %s"):format(vim.fn.string(msg)))
    end
  end
  vim.cmd("echohl None")
end

function M.echo_url(url)
  M.echo_messages("Type", "Preview page: " .. url)
end

function M.open_preview_page()
  if try_id then
    return
  end
  local status = rpc.get_server_status()
  if status == -1 then
    rpc.start_server()
  elseif status == 0 then
    try_id = vim.defer_fn(try_open_preview_page, 1000)
  else
    M.open_browser()
  end
end

function M.combine_preview_refresh()
  if vim.g.mkdp_clients_active and not vim.g.mkdp_auto_start then
    M.open_browser()
  end
end

function M.open_browser()
  rpc.open_browser()
  autocmd.init()
  vim.api.nvim_exec_autocmds("User", { pattern = "MkdpPreviewStart" })
end

function M.stop_preview()
  vim.g.mkdp_clients_active = 0
  vim.api.nvim_exec_autocmds("User", { pattern = "MkdpPreviewStop" })
  rpc.stop_server()
end

function M.toggle_preview()
  if not vim.b.MarkdownPreviewToggleBool then
    M.open_preview_page()
    vim.b.MarkdownPreviewToggleBool = 1
  else
    M.stop_preview()
    vim.b.MarkdownPreviewToggleBool = 0
  end
end

do
  vim.g.mkdp_auto_start = vim.g.mkdp_auto_start or 0
  vim.g.mkdp_auto_close = vim.g.mkdp_auto_close or 1
  vim.g.mkdp_refresh_slow = vim.g.mkdp_refresh_slow or 0
  vim.g.mkdp_command_for_global = vim.g.mkdp_command_for_global or 0
  vim.g.mkdp_open_to_the_world = vim.g.mkdp_open_to_the_world or 0
  vim.g.mkdp_open_ip = vim.g.mkdp_open_ip or ""
  vim.g.mkdp_echo_preview_url = vim.g.mkdp_echo_preview_url or 0
  vim.g.mkdp_browserfunc = vim.g.mkdp_browserfunc or ""
  vim.g.mkdp_browser = vim.g.mkdp_browser or ""
  vim.g.mkdp_preview_options = vim.g.mkdp_preview_options or {
    mkit = {},
    katex = {},
    uml = {},
    maid = {},
    disable_sync_scroll = 0,
    sync_scroll_type = "middle",
    hide_yaml_meta = 1,
    sequence_diagrams = {},
    flowchart_diagrams = {},
    content_editable = false,
    disable_filename = 0,
    toc = {},
  }
  if not vim.g.mkdp_preview_options.disable_filename then
    vim.g.mkdp_preview_options.disable_filename = 0
  end
  vim.g.mkdp_markdown_css = vim.g.mkdp_markdown_css or ""
  vim.g.mkdp_highlight_css = vim.g.mkdp_highlight_css or ""
  vim.g.mkdp_port = vim.g.mkdp_port or ""
  vim.g.mkdp_page_title = vim.g.mkdp_page_title or "${name}"
  vim.g.mkdp_filetypes = vim.g.mkdp_filetypes or { "markdown" }
  vim.g.mkdp_images_path = vim.g.mkdp_images_path or ""
  vim.g.mkdp_combine_preview = vim.g.mkdp_combine_preview or 0
  vim.g.mkdp_combine_preview_auto_refresh = vim.g.mkdp_combine_preview_auto_refresh or 1
  vim.g.mkdp_clients_active = 0
end

return M
