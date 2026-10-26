local U = require("core.util")
local S = require("core.state")
local UI = require("components")
local Store = require("features.query.store")

local M = {}

local function set_sql(q, text)
  q.sql = text
end

local function status_text(q)
  if q.running then
    return "Running…", "muted"
  end
  if q.err and q.ran then
    return "✕ Failed · " .. q.summary, "danger"
  end
  if q.ran then
    return "✓ " .. q.summary, "success"
  end
  return "F5 runs the SQL above. Enter on a result row shows it in full.", "muted"
end

local function toolbar(q, h)
  h:button({ label = "Run", disabled = q.running, on_click = U.bind(Store.run, q) })
  local text, style = status_text(q)
  h:label({ text = text, style = style })
end

local function results(q, p)
  if q.err then
    UI.error_box(p, "Error", q.err)
  end
  if q.notices then
    UI.error_box(p, "Notices", q.notices)
  end
  if q.result and #q.result.columns > 0 then
    UI.grid.render(p, q.grid, { title = q.title, empty = "The query returned no rows" })
  end
end

local function render(q, p)
  S.active_query = q
  p:input({
    border = true,
    title = "SQL",
    value = q.sql,
    placeholder = "select * from …",
    multiline = true,
    min_rows = 8,
    max_rows = 8,
    autofocus = true,
    margin_top = 1,
    on_change = U.bind(set_sql, q),
  })
  UI.toolbar(p, U.bind(toolbar, q), 0)
  results(q, p)
end

local function on_event(q, ev)
  if ev.type == "key" and ev.key == "F5" then
    Store.run(q)
    return true
  end
end

local function forget(q)
  if S.active_query == q then
    S.active_query = nil
  end
end

function M.page(q)
  return {
    title = q.title,
    render = U.bind(render, q),
    on_event = U.bind(on_event, q),
    on_close = U.bind(forget, q),
  }
end

return M
