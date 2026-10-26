local storage = require("ttt.storage")
local U = require("core.util")

-- Saved connections: { name, uri, host, port, database, user, save_password,
-- password }. The password is stored only when save_password is set;
-- otherwise it lives in M.session until ttt exits.
local M = {}

M.FIELDS = { "uri", "host", "port", "database", "user" }

M.list = {}
M.session = {}

local function hex_char(h)
  return string.char(tonumber(h, 16))
end

local function decode(s)
  return (s:gsub("%%(%x%x)", hex_char))
end

local function split_keywords(conninfo)
  local padded = " " .. conninfo
  local before, password, after = padded:match("^(.-)%spassword%s*=%s*'([^']*)'(.*)$")
  if not before then
    before, password, after = padded:match("^(.-)%spassword%s*=%s*(%S+)(.*)$")
  end
  if not before then
    return conninfo
  end
  return U.trim(before .. after), password
end

-- Moves a password out of a URI's user info or password parameter, or out of
-- a key=value connection string, so it reaches psql through PGPASSWORD and is
-- only saved when the user asks.
function M.split_uri(uri)
  uri = U.trim(uri)
  if uri ~= "" and not uri:find("://", 1, true) then
    return split_keywords(uri)
  end
  local password
  local head, user, pw, rest = uri:match("^(%a[%w+.-]*://)([^:@/]*):([^@/]*)@(.*)$")
  if head then
    password = decode(pw)
    uri = head .. user .. "@" .. rest
  end
  local base, query = uri:match("^([^?]*)%?(.*)$")
  if base then
    local kept = {}
    for _, pair in ipairs(U.split(query, "&")) do
      local v = pair:match("^password=(.*)$")
      if v then
        password = password or decode(v)
      elseif pair ~= "" then
        kept[#kept + 1] = pair
      end
    end
    uri = #kept > 0 and base .. "?" .. table.concat(kept, "&") or base
  end
  return uri, password
end

function M.find(name)
  for i, entry in ipairs(M.list) do
    if entry.name == name then
      return entry, i
    end
  end
end

function M.default_name(conn, except)
  local host, db = U.trim(conn.host), U.trim(conn.database)
  local uri = U.trim(conn.uri)
  if uri ~= "" then
    host = uri:match("://[^/?]*@([^/:?]+)") or uri:match("://([^/:?@]+)") or ""
    db = uri:match("://[^/?]*/([^?]+)") or ""
  end
  local base = db ~= "" and db or "postgres"
  if host ~= "" then
    base = db ~= "" and db .. "@" .. host or host
  end
  local name, n = base, 1
  while true do
    local found = M.find(name)
    if not found or found.name == except then
      return name
    end
    n = n + 1
    name = base .. " " .. n
  end
end

function M.password(entry)
  if entry.save_password then
    return entry.password or ""
  end
  return M.session[entry.name]
end

-- Whether connecting needs no prompt for the password.
function M.ready(entry)
  return entry ~= nil and M.password(entry) ~= nil
end

function M.conn(entry)
  local conn = { password = M.password(entry) or "" }
  for _, key in ipairs(M.FIELDS) do
    conn[key] = entry[key] or ""
  end
  return conn
end

local function save()
  storage.set("connections", M.list)
end

function M.set_active(name)
  storage.set("active", name)
end

-- Replaces the entry called `old_name`, or adds it.
function M.put(entry, old_name)
  local _, i = M.find(old_name or entry.name)
  M.list[i or #M.list + 1] = entry
  if old_name and old_name ~= entry.name then
    M.session[old_name] = nil
  end
  save()
end

function M.remove(name)
  local _, i = M.find(name)
  if i then
    table.remove(M.list, i)
    M.session[name] = nil
    save()
  end
end

-- The single `connection` of earlier versions becomes the first saved
-- connection, password included, so it keeps connecting without a prompt.
local function migrate(old)
  local entry = { save_password = true }
  for _, key in ipairs(M.FIELDS) do
    entry[key] = U.trim(old[key])
  end
  local uri, uri_password = M.split_uri(entry.uri)
  entry.uri = uri
  entry.password = (old.password and old.password ~= "") and old.password or uri_password or ""
  entry.name = M.default_name(entry)
  M.list = { entry }
  save()
  M.set_active(entry.name)
  storage.remove("connection")
end

function M.load()
  local list = storage.get("connections")
  if type(list) == "table" then
    M.list = list
  else
    local old = storage.get("connection")
    if type(old) == "table" then
      migrate(old)
    end
  end
  local active = storage.get("active")
  return M.find(active) or M.list[1]
end

return M
