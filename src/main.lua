local ttt = require("ttt")
local S = require("core.state")
local Db = require("core.db")
local Sidebar = require("app.sidebar")
local Connection = require("app.connection")
local Connections = require("app.connections")
local Settings = require("app.settings")
local Table = require("features.table")
local Query = require("features.query")

Sidebar.open_relation = Table.open
Sidebar.new_query = Query.new
Table.page.open_query = Query.open_with

local function settings_changed()
  Table.store.reload_all()
  S.redraw()
end

Settings.on_change = settings_changed
Connection.pick = Connections.dialog
Connection.on_connected = settings_changed

local function new_query()
  Query.new()
end

local function refresh()
  Db.refresh()
  Table.store.reload_all()
  S.redraw()
end

local sidebar_actions = {
  connections = Connections.dialog,
  new_connection = Connection.new,
  settings = Settings.dialog,
  query = new_query,
  reconnect = Connection.reconnect,
  refresh = refresh,
}

local function on_action(cmd)
  local run = sidebar_actions[cmd]
  if run then
    run()
  end
end

ttt.register({
  sidebar = {
    title = "Postgres",
    render = Sidebar.render,
    actions = {
      { label = "New Query", command = "query" },
      { label = "Refresh", command = "refresh" },
      { separator = true },
      { label = "Connections…", command = "connections" },
      { label = "New Connection…", command = "new_connection" },
      { label = "Settings…", command = "settings" },
      { label = "Reconnect", command = "reconnect" },
    },
    on_action = on_action,
  },
  commands = {
    { id = "postgres.connections", title = "Postgres: Connections…", handler = Connections.dialog },
    { id = "postgres.connect", title = "Postgres: New Connection…", handler = Connection.new },
    { id = "postgres.newQuery", title = "Postgres: New Query", handler = new_query },
    { id = "postgres.runQuery", title = "Postgres: Run Query", handler = Query.run_active },
    { id = "postgres.refresh", title = "Postgres: Refresh", handler = refresh },
    { id = "postgres.reconnect", title = "Postgres: Reconnect", handler = Connection.reconnect },
    { id = "postgres.settings", title = "Postgres: Settings…", handler = Settings.dialog },
  },
})
