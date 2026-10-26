local U = require("core.util")
local S = require("core.state")
local UI = require("components")
local Router = require("app.router")
local Store = require("features.table.store")
local Structure = require("features.table.structure_tab")

local M = {}

local TABS = { { id = "data", label = "Data" }, { id = "structure", label = "Structure" } }

M.open_query = nil

local function data_tab(p, rel)
  local grid = rel.data
  if not grid.loaded and not grid.loading then
    Store.load_data(rel, 0)
  end
  if grid.err then
    UI.error_box(p, "Couldn't load rows", grid.err)
    return
  end
  UI.grid.render(p, grid, { title = rel.key, empty = "No rows in " .. rel.name })
end

local function refresh(page, rel)
  if page.tab == "structure" then
    Store.load_structure(rel)
  else
    Store.load_data(rel)
  end
end

local function query(rel)
  if M.open_query then
    M.open_query("select *\nfrom " .. U.qualified(rel.schema, rel.name) .. "\nlimit 100;")
  end
end

local function actions(page, rel, h)
  h:button({ label = "Refresh", on_click = U.bind(refresh, page, rel) })
  h:button({ label = "Query", on_click = U.bind(query, rel) })
end

local function render(page, rel, p)
  S.active_query = nil
  local current = Router.tab_strip(p, page, TABS)
  if current == "structure" then
    Structure.render(p, rel)
  else
    data_tab(p, rel)
  end
end

function M.page(rel)
  local page = { title = rel.key, tab_title = rel.name, on_close = U.bind(Store.forget, rel.key) }
  page.actions = U.bind(actions, page, rel)
  page.render = U.bind(render, page, rel)
  return page
end

return M
