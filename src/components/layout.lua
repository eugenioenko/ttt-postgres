local text = require("ttt.text")
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

-- One label per line, so psql's caret under the error position lines up.
function M.error_box(p, title, message)
  local width = 0
  if p.size then
    width = p:size() - 6
  end
  local lines = {}
  for _, line in ipairs(U.split(U.trim(message), "\n")) do
    if width > 20 then
      for _, part in ipairs(text.wrap(line, width)) do
        lines[#lines + 1] = part
      end
    else
      lines[#lines + 1] = line
    end
  end
  M.frame(p, title, U.bind(error_lines, lines), { height = #lines + 3, margin_top = 1 })
end

return M
