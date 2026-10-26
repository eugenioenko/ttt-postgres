local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local Db = require("core.db")
local Connection = require("app.connection")

-- Every table and query gets its own editor tab. A tab holds a page,
-- { title, tab_title?, render(p, tab), actions(h, tab)?, on_event(ev, tab)?,
-- on_close()? }; actions draw on the right of the title row.
local M = {}

M.tabs = {}

local function title_row(tab, h)
  h:label({ text = tab.page.title, style = "bold", padding_left = 1 })
  if tab.page.actions and S.status == "ok" then
    tab.page.actions(h, tab)
  end
end

local function render(tab, p)
  S.panels[tab.id] = p
  Db.ensure_connected()
  p:hstack({ height = 1, gap = 1, render = U.bind(title_row, tab) })
  if S.status ~= "ok" then
    Connection.not_connected(p)
    return
  end
  tab.page.render(p, tab)
end

local function on_event(tab, ev)
  if tab.page.on_event then
    return tab.page.on_event(ev, tab)
  end
end

local function forget(tab)
  S.panels[tab.id] = nil
  M.tabs[tab.id] = nil
  if tab.page.on_close then
    tab.page.on_close()
  end
end

-- Opens a page in its own tab, keyed by what it shows, or focuses that tab
-- when it is already open; ttt ignores the rest of the config then.
function M.show(key, make_page, focus)
  local tab = M.tabs[key]
  if not tab then
    tab = { id = key, page = make_page() }
    M.tabs[key] = tab
  end
  local config = {
    id = tab.id,
    title = tab.page.tab_title or tab.page.title,
    render = U.bind(render, tab),
    on_event = U.bind(on_event, tab),
    on_close = U.bind(forget, tab),
  }
  ttt.open_tab(config)
  -- Opening an id that is open is the only way to focus a tab, and a click in
  -- the sidebar takes focus back after its callback, so it waits a tick.
  if focus then
    ttt.set_timeout(1, U.bind(ttt.open_tab, config))
  end
  return tab
end

local function select_tab(page, id)
  page.tab = id
  S.redraw()
end

-- Draws a page's tab strip and returns the active tab id.
function M.tab_strip(p, page, items)
  page.tab = page.tab or items[1].id
  p:tabs({ items = items, active = page.tab, margin_top = 1, on_change = U.bind(select_tab, page) })
  return page.tab
end

return M
