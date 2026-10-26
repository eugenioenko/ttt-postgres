local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local Saved = require("core.saved")
local Db = require("core.db")
local UI = require("components")

local M = {}

M.pick = nil
M.on_connected = nil

local PLAIN_TEXT = "⚠ The password is stored in plain text in ttt's plugin storage."
  .. " Only save it for local, non-sensitive credentials."
local SESSION_ONLY = "The password is used until ttt exits and is not saved."

local function password_note(vals)
  if vals.save_password then
    return PLAIN_TEXT, "warning"
  end
  return SESSION_ONLY, "muted"
end

local function after_connect()
  ttt.notify("Connected to " .. Db.label())
  if M.on_connected then
    M.on_connected()
  end
end

-- A failed attempt stays in memory for Retry but is not saved.
local function connected(entry, old_name, password, done, err)
  if err then
    return done(err)
  end
  Saved.put(entry, old_name)
  Saved.session[entry.name] = not entry.save_password and password or nil
  Saved.set_active(entry.name)
  S.entry = entry
  after_connect()
  done()
end

local function connect(old_name, v, done)
  local entry = { save_password = v.save_password == true }
  for _, key in ipairs(Saved.FIELDS) do
    entry[key] = U.trim(v[key])
  end
  local uri, uri_password = Saved.split_uri(entry.uri)
  entry.uri = uri
  local password = v.password ~= "" and v.password or uri_password or ""
  entry.password = entry.save_password and password or nil
  entry.name = U.trim(v.name)
  if entry.name == "" then
    entry.name = Saved.default_name(entry, old_name)
  end
  local taken = Saved.find(entry.name)
  if taken and entry.name ~= old_name then
    return done("A saved connection is already called " .. entry.name)
  end
  S.conn = Saved.conn(entry)
  S.conn.password = password
  S.server = nil
  Db.connect(U.bind(connected, entry, old_name, password, done))
end

local function form(title, entry, focus)
  local conn = entry and Saved.conn(entry) or S.default_conn()
  UI.dialog({
    title = title,
    submit = "Connect",
    busy_text = "Connecting…",
    hint = "A connection URI replaces the host, port, database and user.",
    width = 76,
    focus = focus,
    fields = {
      {
        key = "name",
        label = "Name",
        value = entry and entry.name or "",
        placeholder = "database@host when empty",
      },
      {
        key = "uri",
        label = "Connection URI (optional)",
        value = conn.uri,
        placeholder = "postgresql://user@localhost:5432/postgres",
      },
      { key = "host", label = "Host", value = conn.host, placeholder = "localhost" },
      { key = "port", label = "Port", value = conn.port, placeholder = "5432" },
      { key = "database", label = "Database", value = conn.database, placeholder = "postgres" },
      { key = "user", label = "User", value = conn.user, placeholder = "postgres" },
      {
        key = "password",
        label = "Password (empty uses PGPASSWORD or ~/.pgpass)",
        value = conn.password,
        password = true,
      },
      { key = "save_password", kind = "checkbox", label = "Save password", value = entry and entry.save_password },
      { key = "password_note", kind = "note", rows = 2, note = password_note },
    },
    on_submit = U.bind(connect, entry and entry.name),
  })
end

function M.new()
  form("New PostgreSQL Connection")
end

function M.edit(name)
  local entry = Saved.find(name)
  if entry then
    form("Edit " .. name, entry)
  end
end

local function used(err)
  if not err then
    after_connect()
  end
end

-- Connects to a saved connection, or asks for its password first when it
-- has none for this session.
function M.use(name)
  local entry = Saved.find(name)
  if not entry then
    return
  end
  if not Saved.ready(entry) then
    form("Connect to " .. name, entry, "password")
    return
  end
  S.entry = entry
  S.conn = Saved.conn(entry)
  S.server = nil
  Saved.set_active(name)
  Db.connect(used)
end

function M.reconnect()
  if S.status == "idle" and not S.configured() then
    if S.entry then
      return M.use(S.entry.name)
    end
    return M.new()
  end
  Db.connect()
end

local function pick()
  if M.pick then
    M.pick()
  end
end

local function buttons(h)
  if #Saved.list > 0 then
    h:button({ label = "Connections…", on_click = pick })
  else
    h:button({ label = "New Connection…", on_click = M.new })
  end
  if S.status == "error" then
    h:button({ label = "Retry", on_click = Db.connect })
  elseif S.status == "idle" and S.entry then
    h:button({ label = "Connect", on_click = M.reconnect })
  end
end

-- Shown in a tab while there is no working connection.
function M.not_connected(p)
  local text = "Not connected."
  if S.status == "connecting" then
    text = "Connecting to " .. Db.label() .. "…"
  elseif S.entry and not S.configured() then
    text = "Not connected. " .. S.entry.name .. " asks for its password on connect."
  elseif not S.entry then
    text = #Saved.list > 0 and "Not connected. Choose a saved connection." or "No saved connection. Set one up first."
  end
  if S.status == "error" then
    UI.error_box(p, "Couldn't connect to " .. Db.label(), S.message)
  else
    p:label({ text = text, style = "muted", margin_top = 1, padding_left = 1 })
  end
  p:hstack({ height = 1, gap = 1, margin_top = 1, padding_left = 1, render = buttons })
end

return M
