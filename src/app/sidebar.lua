local U = require("core.util")
local S = require("core.state")
local Db = require("core.db")
local UI = require("components")
local Saved = require("core.saved")
local Connection = require("app.connection")
local Connections = require("app.connections")

local M = {}

M.open_relation = nil
M.new_query = nil

local function status_item()
  local label = Db.label()
  if S.status == "ok" then
    return { id = "conn", icon = "●", label = label }
  elseif S.status == "connecting" then
    return { id = "conn", icon = "◌", label = "Connecting to " .. label .. "…", muted = true }
  elseif S.status == "error" then
    return { id = "conn", icon = "✕", label = label .. " · not connected", muted = true }
  end
  if S.entry then
    return { id = "conn", icon = "○", label = S.entry.name .. " · not connected", muted = true }
  elseif #Saved.list > 0 then
    return { id = "conn", icon = "○", label = "Choose a connection…", muted = true }
  end
  return { id = "conn", icon = "○", label = "Set up connection…", muted = true }
end

local function matches(r)
  return S.filter == "" or r.name:lower():find(S.filter:lower(), 1, true) ~= nil
end

local function badge(r)
  if r.relkind == "m" then
    return "mat"
  elseif r.relkind == "f" then
    return "foreign"
  elseif r.kind == "view" then
    return nil
  end
  return r.estimate and r.estimate >= 0 and U.count(r.estimate) or nil
end

local function group(id, label, children)
  return { id = id, label = label, badge = tostring(#children), expanded = true, children = children }
end

local function tree_items()
  local tables, views = {}, {}
  for _, r in ipairs(S.relations) do
    if matches(r) then
      local node = { id = "rel:" .. r.name, label = r.name, badge = badge(r) }
      if r.kind == "view" then
        views[#views + 1] = node
      else
        tables[#tables + 1] = node
      end
    end
  end
  local items = {}
  if #tables > 0 or #views == 0 then
    items[#items + 1] = group("group:tables", "Tables", tables)
  end
  if #views > 0 then
    items[#items + 1] = group("group:views", "Views", views)
  end
  return items
end

local function find_relation(name)
  for _, r in ipairs(S.relations) do
    if r.name == name then
      return r
    end
  end
end

local function open_node(node)
  local name = node.id:match("^rel:(.*)$")
  local r = name and find_relation(name)
  if r and M.open_relation then
    M.open_relation(S.schema, r.name, r.kind)
  end
end

-- "activate" comes on every click and Enter, also for the row that is already
-- selected, which on_select misses; arrowing only moves.
local function on_tree_command(command, node)
  if command == "activate" then
    open_node(node)
  end
end

local function on_link_command(command, node)
  if command ~= "activate" then
    return
  end
  if node.id == "conn" then
    if #Saved.list > 0 then
      Connections.dialog()
    else
      Connection.new()
    end
  elseif node.id == "query" and M.new_query then
    M.new_query()
  end
end

local function schema_options()
  local options = {}
  for i, name in ipairs(S.schemas) do
    options[i] = { label = name, value = name }
  end
  return options
end

local function schema_row(h)
  h:label({ text = "Schema", style = "muted", width = 7 })
  UI.dropdown(h, schema_options(), S.schema, Db.set_schema, S.schema)
end

local function set_filter(text)
  S.filter = text
  S.redraw()
end

local function message()
  if S.status ~= "ok" then
    return "", "muted"
  end
  if S.relations_err then
    return "✕ " .. S.relations_err, "danger"
  end
  if S.relations_loading and #S.relations == 0 then
    return "Loading…", "muted"
  end
  if #S.relations == 0 then
    return "No tables or views in " .. S.schema, "muted"
  end
  return "", "muted"
end

local function short_error(text)
  local first = U.split(text, "\n")[1]
  return first:match("FATAL:%s+(.*)$") or first
end

local function links(items, b)
  b:list({ items = items, inset = 1, on_command = on_link_command })
end

function M.render(p)
  S.panels.sidebar = p
  Db.ensure_connected()
  p:hstack({ height = 1, gap = 1, margin_top = 1, padding_left = 1, render = schema_row })
  p:input({
    placeholder = "Filter tables…",
    prefix = "⌕ ",
    value = S.filter,
    margin_top = 1,
    on_change = set_filter,
  })
  p:tree({
    items = S.status == "ok" and tree_items() or {},
    inset = 1,
    badge_right = true,
    on_command = on_tree_command,
  })
  local text, style = message()
  p:label({ text = text, style = style, padding_left = 1 })
  if S.status == "error" then
    p:label({ text = "✕ " .. short_error(S.message), style = "danger", padding_left = 1 })
  end
  p:divider()
  local items = { { id = "query", icon = "+", label = "New Query", muted = S.status ~= "ok" }, status_item() }
  p:box({ height = #items, render = U.bind(links, items) })
end

return M
