local M = {}

local roots = {}
local files = {}
local icon = "󰋊"
local fg = nil

local function clean(path)
  if path ~= "/" then
    path = path:gsub("/+$", "")
  end
  return path
end

local function clean_all(values)
  local out = {}
  for _, value in ipairs(values) do
    out[#out + 1] = clean(value)
  end
  return out
end

local function under(path, root)
  if root == "/" then
    return path:sub(1, 1) == "/"
  end
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

local function is_local(url)
  return tostring(url):sub(1, 1) == "/"
end

function M.setup(opts)
  opts = opts or {}
  roots = clean_all(opts.roots or {})
  files = clean_all(opts.files or {})
  icon = opts.icon or icon
  fg = opts.fg
end

function M.marker(url, hovered)
  if not url or not is_local(url) then
    return ""
  end

  local path = clean(tostring(url.path))
  local persisted = false

  for _, file in ipairs(files) do
    if path == file then
      persisted = true
      break
    end
  end

  if not persisted then
    for _, root in ipairs(roots) do
      if under(path, root) then
        persisted = true
        break
      end
    end
  end

  if not persisted then
    return ""
  end
  if hovered or not fg then
    return icon
  end

  return ui.Line {
    ui.Span(icon):style(ui.Style():fg(fg)),
  }
end

return M
