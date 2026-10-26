local ttt = require("ttt")
local storage = require("ttt.storage")
local U = require("core.util")
local S = require("core.state")
local Db = require("core.db")
local UI = require("components")

local M = {}

local FIELDS = { "uri", "host", "port", "database", "user", "password" }

-- A failed attempt stays in memory for Retry but is not saved.
local function connected(done, err)
  if err then
    return done(err)
  end
  storage.set("connection", S.conn)
  S.saved = true
  ttt.notify("Connected to " .. Db.label())
  done()
end

local function connect(v, done)
  local conn = {}
  for _, key in ipairs(FIELDS) do
    conn[key] = key == "password" and (v[key] or "") or U.trim(v[key])
  end
  S.conn = conn
  S.server = nil
  Db.connect(U.bind(connected, done))
end

function M.dialog()
  UI.dialog({
    title = "PostgreSQL Connection",
    submit = "Connect",
    busy_text = "Connecting…",
    hint = "A connection URI replaces the fields below it.",
    width = 72,
    fields = {
      {
        key = "uri",
        label = "Connection URI (optional)",
        value = S.conn.uri,
        placeholder = "postgresql://user@localhost:5432/postgres",
      },
      { key = "host", label = "Host", value = S.conn.host, placeholder = "localhost" },
      { key = "port", label = "Port", value = S.conn.port, placeholder = "5432" },
      { key = "database", label = "Database", value = S.conn.database, placeholder = "postgres" },
      { key = "user", label = "User", value = S.conn.user, placeholder = "postgres" },
      {
        key = "password",
        label = "Password (empty uses PGPASSWORD or ~/.pgpass)",
        value = S.conn.password,
        password = true,
      },
    },
    on_submit = connect,
  })
end

local function buttons(h)
  h:button({ label = "Connection…", on_click = M.dialog })
  if (S.configured() or S.status == "error") and S.status ~= "connecting" then
    h:button({ label = "Retry", on_click = Db.connect })
  end
end

-- Shown in a tab while there is no working connection.
function M.not_connected(p)
  local text = "Not connected."
  if S.status == "connecting" then
    text = "Connecting to " .. Db.label() .. "…"
  elseif not S.configured() then
    text = "Not configured. Set up the connection first."
  end
  if S.status == "error" then
    UI.error_box(p, "Couldn't connect to " .. Db.label(), S.message)
  else
    p:label({ text = text, style = "muted", margin_top = 1, padding_left = 1 })
  end
  p:hstack({ height = 1, gap = 1, margin_top = 1, padding_left = 1, render = buttons })
end

return M
