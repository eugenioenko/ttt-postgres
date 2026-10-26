local U = require("core.util")

local M = {}

local function pick(options, on_pick, command)
  local o = options[tonumber(command)]
  if o then
    on_pick(o.value)
  end
end

-- Menu commands are option positions: ttt ignores menu entries whose command
-- is empty.
function M.dropdown(h, options, value, on_pick, label)
  local entries = {}
  for i, o in ipairs(options) do
    entries[i] = { label = o.label, command = tostring(i), checked = o.value == value }
  end
  h:dropdown({
    label = (label or U.option_label(options, value)) .. " ▾",
    entries = entries,
    on_menu = U.bind(pick, options, on_pick),
  })
end

return M
