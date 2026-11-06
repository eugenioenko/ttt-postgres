local ttt = require("ttt")
local S = require("core.state")
local Grid = require("components.grid")
local Router = require("app.router")
local Table = require("features.table")
local Query = require("features.query")
local U = require("core.util")

S.status = "ok"
local rel = Table.store.relation("public", "people")
rel.data.columns = { "id", "name", "notes" }
rel.data.rows = { { "1", "Alice", "First line\nSecond line" }, { "2", "Bob", "Another row" } }
rel.data.total = 2
rel.data.loaded = true

local function open_table()
  Router.show("fixture", U.bind(Table.page.page, rel), true)
end

local function open_query()
  local q = Query.new()
  q.ran = true
  q.summary = "1 row"
  q.result = { columns = { "value" }, rows = { { string.rep("界", 300) .. "\nEND OF LONG VALUE" } } }
  Grid.set_result(q.grid, q.result)
end

local function replace()
  rel.data.rows = { { "1", "Carol", "Refreshed content" } }
  S.redraw()
end

ttt.register({
  commands = {
    { id = "rows.table", title = "Rows: Table", handler = open_table },
    { id = "rows.query", title = "Rows: Query", handler = open_query },
    { id = "rows.replace", title = "Rows: Replace", handler = replace },
  },
})
