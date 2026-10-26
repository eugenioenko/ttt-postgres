local U = require("core.util")

local M = {}

local function merge(into, opts)
  for k, v in pairs(opts or {}) do
    into[k] = v
  end
  return into
end

function M.frame(p, title, render, opts)
  p:box(merge({ border = true, title = title, render = render }, opts))
end

function M.toolbar(p, render, margin_top)
  p:hstack({ height = 1, gap = 1, margin_top = margin_top == nil and 1 or margin_top, render = render })
end

function M.kv(entries)
  local out = { padding_left = 1, margin_top = 1, muted_keys = true }
  for _, e in ipairs(entries) do
    out[#out + 1] = { key = e[1], value = e[2] or "" }
  end
  return out
end

function M.status(p, text, style)
  p:label({ text = text or "", style = style or "muted", padding_left = 1 })
end

local function error_lines(lines, b)
  for _, line in ipairs(lines) do
    b:label({ text = line, style = "danger", padding_left = 1 })
  end
end

local function wrap(out, line, width)
  while #line > width do
    local cut = line:sub(1, width):find(" [^ ]*$")
    if not cut or cut < width / 2 then
      cut = width
    end
    out[#out + 1] = line:sub(1, cut)
    line = line:sub(cut + 1)
  end
  out[#out + 1] = line
end

-- One label per line, so psql's caret under the error position lines up.
function M.error_box(p, title, text)
  local width = 0
  if p.size then
    width = p:size() - 6
  end
  local lines = {}
  for _, line in ipairs(U.split(U.trim(text), "\n")) do
    if width > 20 then
      wrap(lines, line, width)
    else
      lines[#lines + 1] = line
    end
  end
  M.frame(p, title, U.bind(error_lines, lines), { height = #lines + 3, margin_top = 1 })
end

return M
