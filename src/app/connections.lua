local ttt = require("ttt")
local text = require("ttt.text")
local S = require("core.state")
local Saved = require("core.saved")
local UI = require("components")
local Connection = require("app.connection")

local M = {}

local COLUMNS =
  { { label = "", width = 1 }, { label = "Name" }, { label = "Password", width = 15 }, { label = "Server" } }
local MAX_ROWS = 12

local view = { sel = 1, deleting = nil }

local function server(e)
  if e.uri ~= "" then
    return e.uri
  end
  return e.user .. "@" .. e.host .. ":" .. e.port .. "/" .. e.database
end

local function password_state(e)
  if e.save_password then
    return (e.password or "") ~= "" and "saved" or "none"
  end
  return Saved.session[e.name] and "this session" or "asks on connect"
end

local function rows()
  local out = {}
  for i, e in ipairs(Saved.list) do
    local current = S.entry and S.entry.name == e.name and S.status == "ok"
    out[i] = { current and "●" or "", e.name, password_state(e), server(e) }
  end
  return out
end

local function selected()
  local e = Saved.list[view.sel]
  return e and e.name
end

local function select_row(i)
  view.sel = i
  view.deleting = nil
  S.redraw()
end

local function close_then(fn, name)
  ttt.close_dialog()
  fn(name)
end

local function connect_row(i)
  view.sel = i
  local name = selected()
  if name then
    close_then(Connection.use, name)
  end
end

local function connect_selected()
  connect_row(view.sel)
end

local function edit_selected()
  local name = selected()
  if name then
    close_then(Connection.edit, name)
  end
end

local function new_connection()
  close_then(Connection.new)
end

local function ask_delete()
  view.deleting = selected()
  S.redraw()
end

local function cancel_delete()
  view.deleting = nil
  S.redraw()
end

local function confirm_delete()
  local name = view.deleting
  view.deleting = nil
  Saved.remove(name)
  if S.entry and S.entry.name == name then
    S.entry = nil
    Saved.set_active(nil)
  end
  view.sel = math.max(math.min(view.sel, #Saved.list), 1)
  S.redraw()
end

local function buttons(h)
  if view.deleting then
    h:label({ text = "Delete " .. view.deleting .. "?", style = "warning" })
    h:button({ label = "Cancel", style = "muted", on_click = cancel_delete })
    h:button({ label = "Delete", style = "bracket", on_click = confirm_delete })
    return
  end
  local none = #Saved.list == 0
  h:button({ label = "Connect", disabled = none, on_click = connect_selected })
  h:button({ label = "Edit", disabled = none, on_click = edit_selected })
  h:button({ label = "Delete", disabled = none, on_click = ask_delete })
  h:button({ label = "New…", on_click = new_connection })
  h:button({ label = "Close", style = "muted", on_click = ttt.close_dialog })
end

-- The server column takes what the others leave and ends in an ellipsis,
-- so the dialog never scrolls sideways.
local function list(b)
  local columns, cells = UI.grid.fit(COLUMNS, rows())
  local room = b:size() - 2 - 2 * (#columns - 1)
  for i = 1, #columns - 1 do
    room = room - columns[i].width
  end
  columns[#columns].min_width = nil
  for _, line in ipairs(cells) do
    line[#columns] = text.truncate(line[#columns], math.max(room, 1), "…")
  end
  b:table({
    inset = 1,
    columns = columns,
    rows = cells,
    selected = view.sel,
    empty = "No saved connections. New… adds one.",
    on_select = select_row,
    on_activate = connect_row,
  })
end

local function render(p)
  local n = math.min(math.max(#Saved.list, 1), MAX_ROWS)
  p:box({ height = n + 2, margin_top = 1, render = list })
  p:label({ text = "Enter connects to the selected connection.", style = "muted", margin_top = 1, padding_left = 1 })
  p:hstack({ height = 1, gap = 1, margin_top = 1, padding_left = 1, render = buttons })
end

function M.dialog()
  view.deleting = nil
  for i, e in ipairs(Saved.list) do
    if S.entry and e.name == S.entry.name then
      view.sel = i
    end
  end
  view.sel = math.max(math.min(view.sel, #Saved.list), 1)
  local n = math.min(math.max(#Saved.list, 1), MAX_ROWS)
  UI.open_dialog("PostgreSQL Connections", 96, n + 7, render)
end

return M
