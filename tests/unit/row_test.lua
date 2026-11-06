local Grid = require("components.grid")
local Row = require("features.row")
local Router = require("app.router")
local Psql = require("core.psql")
local text = require("ttt.text")

local function entries(tab, width)
  local out
  local panel = {}
  function panel:size()
    return width, 30
  end
  function panel:scrollview(config)
    config.render(self)
  end
  function panel:keyvalue(values)
    out = values
  end
  tab.page.render(panel)
  local values = {}
  for _, entry in ipairs(out) do
    values[#values + 1] = entry
  end
  return values
end

local function tabs(t)
  local first = Grid.new({ columns = { "id" }, rows = { { "1" }, { "2" } }, offset = 50 })
  local tab = Row.show(first, "public.people", 1)
  t.eq(tab.page.title, "public.people · row 51")
  t.eq(Row.show(first, "public.people", 1), tab, "reopening focuses the existing page")
  t.ok(Row.show(first, "public.people", 2).id ~= tab.id, "another row has another tab")
  local second = Grid.new({ columns = { "id" }, rows = { { "1" } } })
  t.ok(Row.show(second, "public.people", 1).id ~= tab.id, "another result has another tab")
  t.eq(Row.show(first, "public.people", 3), nil, "missing row")
  t.eq(Router.tabs[tab.id], tab)
end

local function snapshot(t)
  local grid = Grid.new({ columns = { "name" }, rows = { { "Alice" } } })
  local tab = Row.show(grid, "Query 1", 1)
  grid.columns[1] = "changed"
  grid.rows[1][1] = "Bob"
  t.eq(entries(tab, 80), { { key = "name", value = "Alice" } }, "an open tab keeps its values")
  Grid.set_result(grid, { columns = { "name" }, rows = { { "Carol" } } })
  local refreshed = Row.show(grid, "Query 1", 1)
  t.ok(refreshed.id ~= tab.id, "a rerun opens a new result snapshot")
  t.eq(entries(refreshed, 80), { { key = "name", value = "Carol" } })
end

local function values(t)
  local grid = Grid.new({
    columns = { "null", "empty", "lines", "missing" },
    rows = { { Psql.NULL, "", "first\r\nsecond\n" } },
  })
  t.eq(entries(Row.show(grid, "Query 2", 1), 80), {
    { key = "null", value = "NULL" },
    { key = "empty", value = "" },
    { key = "lines", value = "first" },
    { key = "", value = "second" },
    { key = "", value = "" },
    { key = "missing", value = "" },
  })
end

local function wrap(t)
  local value = string.rep("界", 300)
  local grid = Grid.new({ columns = { "内容" }, rows = { { value } } })
  local tab = Row.show(grid, "Query 3", 1)
  for _, width in ipairs({ 40, 100 }) do
    local lines = entries(tab, width)
    local restored = {}
    for _, entry in ipairs(lines) do
      t.ok(text.width(entry.value) <= width - 11, "wrapped value fits the tab")
      restored[#restored + 1] = entry.value
    end
    t.eq(table.concat(restored), value, "full value survives wrapping and resize")
  end
end

return {
  { "row tabs reuse a page and distinguish result rows", tabs },
  { "row tabs snapshot values across refreshes", snapshot },
  { "row tabs preserve NULL, empty and multiline values", values },
  { "row tabs wrap fullwidth values to the available width", wrap },
}
