-- The component library as one table, so callers write UI.frame, UI.dialog, …
local UI = {}

for _, name in ipairs({ "layout", "inputs", "form", "dialog" }) do
  for k, v in pairs(require("components." .. name)) do
    assert(UI[k] == nil, "components: " .. k .. " is defined twice")
    UI[k] = v
  end
end

UI.grid = require("components.grid")

return UI
