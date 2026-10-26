local storage = require("ttt.storage")
local U = require("core.util")
local S = require("core.state")
local Psql = require("core.psql")
local SQL = require("core.sql")

local Db = {}

local KINDS = { r = "table", p = "table", f = "table", v = "view", m = "view" }

local function pick_schema()
  for _, name in ipairs(S.schemas) do
    if name == S.schema then
      return
    end
  end
  S.schema = "public"
  for _, name in ipairs(S.schemas) do
    if name == "public" then
      return
    end
  end
  S.schema = S.schemas[1] or "public"
end

local function relations_loaded(gen, err, sets)
  if gen ~= S.relations_gen then
    return
  end
  S.relations_loading = false
  S.relations_err = err
  local list = {}
  for _, r in ipairs(not err and sets[1] and sets[1].rows or {}) do
    list[#list + 1] = { name = r[1], relkind = r[2], kind = KINDS[r[2]] or "table", estimate = tonumber(r[3]) }
  end
  S.relations = list
  S.redraw()
end

function Db.load_relations()
  if S.status ~= "ok" then
    return
  end
  S.relations_gen = S.relations_gen + 1
  S.relations_loading = true
  S.relations_err = nil
  S.redraw()
  Psql.query(SQL.relations(S.schema), U.bind(relations_loaded, S.relations_gen))
end

function Db.set_schema(name)
  if name == S.schema then
    return
  end
  S.schema = name
  S.relations = {}
  storage.set("schema", name)
  Db.load_relations()
end

local function connected(gen, cb, err, sets)
  if gen ~= S.gen then
    return
  end
  if err then
    S.status = "error"
    S.message = err
  else
    local info = sets[1] and sets[1].rows[1] or {}
    S.status = "ok"
    S.message = ""
    S.server = { user = info[1], database = info[2], host = info[3], port = info[4], version = info[5] }
    S.schemas = {}
    for _, r in ipairs(sets[2] and sets[2].rows or {}) do
      S.schemas[#S.schemas + 1] = r[1]
    end
    pick_schema()
    Db.load_relations()
  end
  S.redraw()
  if cb then
    cb(err)
  end
end

function Db.connect(cb)
  S.gen = S.gen + 1
  S.status = "connecting"
  S.message = ""
  S.redraw()
  Psql.query(SQL.CONNECT, U.bind(connected, S.gen, cb))
end

function Db.ensure_connected()
  if S.status == "idle" and S.configured() then
    Db.connect()
  end
end

function Db.refresh()
  if S.status == "ok" then
    Db.load_relations()
  else
    Db.connect()
  end
end

-- What the status line calls the server.
function Db.label()
  local c = S.conn
  local uri = U.trim(c.uri)
  if S.server then
    local host = uri ~= "" and uri:match("@([^/?]+)") or (uri == "" and c.host .. ":" .. c.port) or nil
    if not host then
      host = S.server.host .. (S.server.port ~= "" and ":" .. S.server.port or "")
    end
    return S.server.user .. "@" .. host .. "/" .. S.server.database
  end
  if uri ~= "" then
    local uri = U.trim(c.uri):gsub("://([^:@/]*):[^@]*@", "://%1@")
    return (uri:gsub("password=%S+", "password=…"))
  end
  return c.user .. "@" .. c.host .. ":" .. c.port .. "/" .. c.database
end

return Db
